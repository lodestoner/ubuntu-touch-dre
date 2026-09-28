#!/usr/bin/env python3
"""Binary-patch /init inside a cpio newc archive without changing any headers."""

import struct
import sys

def parse_hex(data, offset, length):
    return int(data[offset:offset+length].decode('ascii'), 16)

def find_and_patch_init(cpio_data, replacement_binary):
    """Find the /init entry in cpio and replace its file data."""
    pos = 0
    while pos < len(cpio_data) - 110:
        # Look for cpio magic
        if cpio_data[pos:pos+6] != b'070701':
            pos += 1
            continue

        # Parse header
        filesize = parse_hex(cpio_data, pos + 54, 8)
        namesize = parse_hex(cpio_data, pos + 94, 8)

        # Filename starts at pos + 110, padded to 4-byte boundary
        name_start = pos + 110
        name_end = name_start + namesize
        name_padded = name_end + ((4 - (name_end % 4)) % 4)

        filename = cpio_data[name_start:name_start + namesize - 1]  # -1 for null terminator

        # Data starts after padded filename
        data_start = name_padded
        data_end = data_start + filesize
        data_padded = data_end + ((4 - (data_end % 4)) % 4)

        if filename == b'init':
            print(f"Found /init at cpio offset {pos}")
            print(f"  Header: {pos}-{pos+110}")
            print(f"  Filename: {name_start}-{name_end} (padded to {name_padded})")
            print(f"  Data: {data_start}-{data_end} ({filesize} bytes)")
            print(f"  Next entry: {data_padded}")
            print(f"  Replacement binary: {len(replacement_binary)} bytes")

            if len(replacement_binary) > filesize:
                print(f"ERROR: replacement ({len(replacement_binary)}) larger than original ({filesize})")
                sys.exit(1)

            # Replace file data: our binary + zero padding
            result = bytearray(cpio_data)
            result[data_start:data_start + len(replacement_binary)] = replacement_binary
            result[data_start + len(replacement_binary):data_end] = b'\x00' * (filesize - len(replacement_binary))

            print(f"  Patched {len(replacement_binary)} bytes + {filesize - len(replacement_binary)} zero-fill")

            # Verify ELF header at the patched location
            if result[data_start:data_start+4] == b'\x7fELF':
                print("  ELF magic verified at patched location")

            return bytes(result)

        # Move to next entry
        pos = data_padded

    print("ERROR: /init not found in cpio")
    sys.exit(1)

if __name__ == '__main__':
    cpio_path = sys.argv[1]
    binary_path = sys.argv[2]
    output_path = sys.argv[3]

    with open(cpio_path, 'rb') as f:
        cpio_data = f.read()
    with open(binary_path, 'rb') as f:
        replacement = f.read()

    patched = find_and_patch_init(cpio_data, replacement)

    with open(output_path, 'wb') as f:
        f.write(patched)

    print(f"\nWrote patched cpio to {output_path}")
