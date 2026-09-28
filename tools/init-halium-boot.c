/*
 * Halium-style init bootstrap: mount core filesystems, open console,
 * then exec BusyBox sh with USB debug script.
 *
 * Compile: clang --target=aarch64-linux-gnu -static -nostdlib -ffreestanding
 *          -O2 -o init-halium-boot init-halium-boot.c
 */

typedef unsigned long ulong;

static long sc(long n, long a0, long a1, long a2, long a3, long a4)
{
    register long x0 __asm__("x0") = a0;
    register long x1 __asm__("x1") = a1;
    register long x2 __asm__("x2") = a2;
    register long x3 __asm__("x3") = a3;
    register long x4 __asm__("x4") = a4;
    register long x8 __asm__("x8") = n;
    __asm__ volatile("svc 0"
        : "+r"(x0)
        : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x8)
        : "memory");
    return x0;
}

#define SYS_openat   56
#define SYS_close    57
#define SYS_write    64
#define SYS_exit     93
#define SYS_mount    40
#define SYS_mkdirat  34
#define SYS_dup3     24
#define SYS_execve   221

#define AT_FDCWD  (-100)
#define O_RDWR    2
#define O_WRONLY  1
#define O_APPEND  1024

static ulong slen(const char *s)
{
    ulong n = 0;
    while (s[n]) n++;
    return n;
}

static void wr(int fd, const char *s)
{
    sc(SYS_write, fd, (long)s, slen(s), 0, 0);
}

static long do_mount(const char *src, const char *dst, const char *fs, long flags)
{
    return sc(SYS_mount, (long)src, (long)dst, (long)fs, flags, 0);
}

static void do_mkdir(const char *path, int mode)
{
    sc(SYS_mkdirat, AT_FDCWD, (long)path, mode, 0, 0);
}

__asm__(
    ".globl _start\n"
    ".type _start, %function\n"
    "_start:\n"
    "    ldr x0, [sp]\n"
    "    add x1, sp, #8\n"
    "    add x2, x0, #1\n"
    "    add x2, x1, x2, lsl #3\n"
    "    b main\n"
);

void main(long argc, char **argv, char **envp)
{
    /* Mount devtmpfs on /dev — this gives us device nodes */
    do_mount("devtmpfs", "/dev", "devtmpfs", 0);

    /* Open /dev/console as fd 0,1,2 */
    int fd = (int)sc(SYS_openat, AT_FDCWD, (long)"/dev/console", O_RDWR, 0, 0);
    if (fd >= 0) {
        if (fd != 0) { sc(SYS_dup3, fd, 0, 0, 0, 0); sc(SYS_close, fd, 0, 0, 0, 0); }
        sc(SYS_dup3, 0, 1, 0, 0, 0);
        sc(SYS_dup3, 0, 2, 0, 0, 0);
    }

    /* Log to kmsg */
    int kmsg = (int)sc(SYS_openat, AT_FDCWD, (long)"/dev/kmsg", O_WRONLY | O_APPEND, 0, 0);
    wr(kmsg, "<6>DRE-INIT: === Halium bootstrap starting ===\n");

    /* Mount proc, sys, configfs */
    do_mount("proc", "/proc", "proc", 0);
    wr(kmsg, "<6>DRE-INIT: mounted /proc\n");

    do_mount("sysfs", "/sys", "sysfs", 0);
    wr(kmsg, "<6>DRE-INIT: mounted /sys\n");

    do_mkdir("/config", 0755);
    do_mount("configfs", "/config", "configfs", 0);
    wr(kmsg, "<6>DRE-INIT: mounted /config\n");

    /* Create directories busybox/telnet need */
    do_mkdir("/dev/pts", 0755);
    do_mount("devpts", "/dev/pts", "devpts", 0);
    do_mkdir("/tmp", 01777);
    do_mkdir("/run", 0755);
    do_mkdir("/etc", 0755);
    do_mkdir("/var", 0755);
    do_mkdir("/root", 0700);

    wr(kmsg, "<6>DRE-INIT: exec busybox sh /halium-usb-init.sh\n");
    if (kmsg >= 0) sc(SYS_close, kmsg, 0, 0, 0, 0);

    /* Exec BusyBox shell with our USB init script */
    char *sh_argv[] = { "/bin/busybox", "sh", "/halium-usb-init.sh", 0 };
    sc(SYS_execve, (long)"/bin/busybox", (long)sh_argv, (long)envp, 0, 0);

    /* If busybox exec fails, try the fallback script location */
    char *sh_argv2[] = { "/bin/busybox", "sh", "-c",
        "echo BUSYBOX RUNNING; mount; ls -la /; exec sh", 0 };
    sc(SYS_execve, (long)"/bin/busybox", (long)sh_argv2, (long)envp, 0, 0);

    /* Last resort: hang with kmsg message */
    int k2 = (int)sc(SYS_openat, AT_FDCWD, (long)"/dev/kmsg", O_WRONLY | O_APPEND, 0, 0);
    wr(k2, "<3>DRE-INIT: FATAL - busybox exec failed\n");
    for (;;) { struct { long s; long ns; } ts = { 3600, 0 };
        sc(115 /*clock_nanosleep*/, 1, 0, (long)&ts, 0, 0); }
}
