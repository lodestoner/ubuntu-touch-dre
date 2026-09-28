#!/usr/bin/env python3
import fcntl
import grp
import os
import struct
import sys
import time
from pathlib import Path


ABS_MT_WIDTH_MAJOR = 0x32
ABS_MT_PRESSURE = 0x3A
INPUT_ABSINFO_SIZE = struct.calcsize("6i")
GPU_NODES = (Path("/dev/kgsl-3d0"), Path("/dev/ion"))


def repair_touch_axes(descriptor, ioctl=fcntl.ioctl):
    for axis in (ABS_MT_WIDTH_MAJOR, ABS_MT_PRESSURE):
        info = bytearray(INPUT_ABSINFO_SIZE)
        ioctl(descriptor, 0x80184540 + axis, info, True)
        value, minimum, maximum, fuzz, flat, resolution = struct.unpack("6i", info)
        if minimum == maximum:
            corrected = struct.pack("6i", value, minimum, minimum + 255, fuzz, flat, resolution)
            ioctl(descriptor, 0x401845C0 + axis, corrected)


def find_touch_event(input_root=Path("/sys/class/input")):
    for event in sorted(input_root.glob("event*")):
        try:
            if (event / "device/name").read_text().strip() == "touchpanel":
                return event.name
        except OSError:
            continue
    return None


def wait_for_devices(timeout=60):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        event = find_touch_event()
        if event and all(node.exists() for node in GPU_NODES):
            return event
        time.sleep(0.2)
    raise TimeoutError("touchpanel or GPU nodes did not appear")


def main():
    event = wait_for_devices()
    graphics_gid = grp.getgrnam("android_graphics").gr_gid
    for node in GPU_NODES:
        os.chown(node, 0, graphics_gid)
        os.chmod(node, 0o660)

    x11_directory = Path("/tmp/.X11-unix")
    x11_directory.mkdir(mode=0o1777, exist_ok=True)
    os.chown(x11_directory, 0, 0)
    os.chmod(x11_directory, 0o1777)

    descriptor = os.open(f"/dev/input/{event}", os.O_RDWR | os.O_CLOEXEC)
    try:
        repair_touch_axes(descriptor)
    finally:
        os.close(descriptor)
    print(f"DRE GPU, X11, and touchscreen ready ({event})")


if __name__ == "__main__":
    try:
        main()
    except (OSError, TimeoutError) as error:
        print(f"DRE hardware setup failed: {error}", file=sys.stderr)
        sys.exit(1)
