#!/usr/bin/env python3
"""
inject_xiaomi_sig.py
Extracts the original Xiaomi platform signature (META-INF/ and APK Signing Block v2/v3)
from an original APK (e.g. VoiceAssistAndroidT.apk) and injects it into a rebuilt/stub APK.
"""

import sys
import os
import zipfile
import struct
import io

def inject_signature(orig_apk_path, unsigned_apk_path, output_apk_path):
    if not os.path.exists(orig_apk_path):
        print(f"Error: Original APK not found at {orig_apk_path}")
        sys.exit(1)
    if not os.path.exists(unsigned_apk_path):
        print(f"Error: Target APK not found at {unsigned_apk_path}")
        sys.exit(1)

    print(f"[*] Reading original signature from: {orig_apk_path}")
    with open(orig_apk_path, 'rb') as f:
        orig_data = f.read()

    # Find End of Central Directory (EOCD)
    eocd_pos = orig_data.rfind(b'\x50\x4b\x05\x06')
    if eocd_pos == -1:
        print("Error: Could not find EOCD in original APK")
        sys.exit(1)

    cd_size, cd_offset = struct.unpack('<II', orig_data[eocd_pos+12:eocd_pos+20])
    footer = orig_data[cd_offset-24:cd_offset]
    block_size = struct.unpack('<Q', footer[:8])[0]
    block_start = cd_offset - block_size - 8
    orig_sig_block = orig_data[block_start:cd_offset]
    print(f"[+] Found APK Signing Block: {len(orig_sig_block)} bytes")

    # Extract META-INF from original
    orig_zip = zipfile.ZipFile(orig_apk_path, 'r')
    meta_files = {}
    for name in orig_zip.namelist():
        if name.startswith('META-INF/') and (name.endswith('.RSA') or name.endswith('.SF') or name.endswith('.MF')):
            meta_files[name] = orig_zip.read(name)
            print(f"  - Extracted {name} ({len(meta_files[name])} bytes)")

    # Re-package target APK with original META-INF
    print(f"[*] Merging unsigned APK with META-INF: {unsigned_apk_path}")
    buf = io.BytesIO()
    with zipfile.ZipFile(unsigned_apk_path, 'r') as zin, zipfile.ZipFile(buf, 'w') as zout:
        for item in zin.infolist():
            if not item.filename.startswith('META-INF/'):
                zout.writestr(item, zin.read(item.filename))
        for name, content in meta_files.items():
            zout.writestr(name, content)

    zip_bytes = buf.getvalue()

    # Insert APK Signing Block before Central Directory
    eocd_pos = zip_bytes.rfind(b'\x50\x4b\x05\x06')
    cd_size, cd_offset = struct.unpack('<II', zip_bytes[eocd_pos+12:eocd_pos+20])

    new_zip_data = (
        zip_bytes[:cd_offset] +
        orig_sig_block +
        zip_bytes[cd_offset:eocd_pos] +
        zip_bytes[eocd_pos:eocd_pos+16] +
        struct.pack('<I', cd_offset + len(orig_sig_block)) +
        zip_bytes[eocd_pos+20:]
    )

    with open(output_apk_path, 'wb') as f:
        f.write(new_zip_data)

    print(f"[+] Successfully wrote signed APK: {output_apk_path} ({len(new_zip_data)} bytes)")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: python3 inject_xiaomi_sig.py <original_apk> <unsigned_apk> <output_apk>")
        sys.exit(1)
    inject_signature(sys.argv[1], sys.argv[2], sys.argv[3])
