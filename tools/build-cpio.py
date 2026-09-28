#!/usr/bin/env python3
"""Build a cpio newc archive from a directory with controlled metadata.

Matches the exact format Android/GKI expects:
- uid/gid = 0 (root)
- mtime = 0
- dev = 0:0
- Incrementing inodes from a configurable base
- Specific TRAILER format
"""

import os
import stat
import struct
import sys


def cpio_newc_entry(filename, mode, filesize, data, ino, nlink=1):
    """Create a single cpio newc entry."""
    namesize = len(filename) + 1  # include null terminator

    header = f"070701" \
             f"{ino:08x}" \
             f"{mode:08x}" \
             f"00000000" \
             f"00000000" \
             f"{nlink:08x}" \
             f"00000000" \
             f"{filesize:08x}" \
             f"00000000" \
             f"00000000" \
             f"00000000" \
             f"00000000" \
             f"{namesize:08x}" \
             f"00000000"

    entry = header.encode('ascii')
    entry += filename.encode('ascii') + b'\x00'

    # Pad name+header to 4-byte boundary
    pad_len = (4 - (len(entry) % 4)) % 4
    entry += b'\x00' * pad_len

    if filesize > 0 and data is not None:
        entry += data
        # Pad data to 4-byte boundary
        pad_len = (4 - (filesize % 4)) % 4
        entry += b'\x00' * pad_len

    return entry


def build_cpio(root_dir, output_path, extra_files=None, ino_base=0x493e0):
    """Build cpio archive from directory.

    extra_files: list of (arcname, filepath, mode) tuples for files to add
                 that aren't in root_dir
    """
    entries = []
    ino = ino_base

    # Collect all entries from the directory (followlinks=False to detect symlinks)
    items = []
    for dirpath, dirnames, filenames in os.walk(root_dir, followlinks=False):
        rel = os.path.relpath(dirpath, root_dir)
        if rel != '.':
            items.append(('dir', rel))
        dirnames.sort()
        for f in sorted(filenames):
            fpath = os.path.join(rel, f) if rel != '.' else f
            full = os.path.join(root_dir, fpath)
            if os.path.islink(full):
                items.append(('symlink', fpath))
            else:
                items.append(('file', fpath))

    # Sort entries alphabetically
    items.sort(key=lambda x: x[1])

    for kind, name in items:
        full_path = os.path.join(root_dir, name)
        if kind == 'dir':
            entry = cpio_newc_entry(name, 0o040755, 0, None, ino, nlink=1)
        elif kind == 'symlink':
            target = os.readlink(full_path)
            data = target.encode('ascii')
            entry = cpio_newc_entry(name, 0o120777, len(data), data, ino, nlink=1)
        else:
            with open(full_path, 'rb') as f:
                data = f.read()
            st = os.stat(full_path)
            mode = st.st_mode & 0o7777
            mode |= 0o100000  # regular file
            entry = cpio_newc_entry(name, mode, len(data), data, ino, nlink=1)
        entries.append(entry)
        ino += 1

    # Add extra files (these go after the directory contents)
    if extra_files:
        for arcname, filepath, mode in extra_files:
            with open(filepath, 'rb') as f:
                data = f.read()
            entry = cpio_newc_entry(arcname, mode, len(data), data, ino, nlink=1)
            entries.append(entry)
            ino += 1

    # TRAILER — match the original's format (non-zero inode, mode 0o755)
    trailer = cpio_newc_entry("TRAILER!!!", 0o000755, 0, None, ino, nlink=1)
    entries.append(trailer)

    # Concatenate
    archive = b''.join(entries)

    # Pad to 256-byte boundary (standard for boot images)
    pad = (256 - (len(archive) % 256)) % 256
    archive += b'\x00' * pad

    with open(output_path, 'wb') as f:
        f.write(archive)

    print(f"Built {output_path}: {len(archive)} bytes, {len(entries)} entries (ino {ino_base:#x}-{ino:#x})")
    return archive


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <root_dir> <output.cpio> [extra_file:arcname:mode ...]")
        sys.exit(1)

    root_dir = sys.argv[1]
    output = sys.argv[2]

    extra = []
    for arg in sys.argv[3:]:
        parts = arg.split(':')
        filepath = parts[0]
        arcname = parts[1] if len(parts) > 1 else os.path.basename(filepath)
        mode = int(parts[2], 8) if len(parts) > 2 else 0o100750
        extra.append((arcname, filepath, mode))

    build_cpio(root_dir, output, extra_files=extra if extra else None)
