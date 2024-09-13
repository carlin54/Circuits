#!/usr/bin/python3

import sys
import hashlib

def load_md5_hashes(file_path):
    """Load all lines from the MD5 hashes file."""
    with open(file_path, 'r') as file:
        lines = file.readlines()

    # Process each line to extract input value, size in bits, and expected hash
    md5_entries = []
    for line in lines:
        input_value, size_in_bits, expected_hash = line.strip().split()
        md5_entries.append((input_value, int(size_in_bits), expected_hash))

    return md5_entries

def verify_md5(input_hex, expected_hash):
    """Verifies the MD5 hash against the expected hash."""
    byte_data = bytes.fromhex(input_hex)
    generated_hash = hashlib.md5(byte_data).hexdigest()
    return generated_hash == expected_hash, generated_hash

if __name__ == "__main__":
    file_path = 'md5_hashes.txt'

    # Load all entries from the file
    md5_entries = load_md5_hashes(file_path)

    # Verify each entry
    for input_hex, size_in_bits, expected_hash in md5_entries:
        is_correct, generated_hash = verify_md5(input_hex, expected_hash)

        if not is_correct:
            print(f"Input Value (Hex): {input_hex}")
            print(f"Size in Bits: {size_in_bits}")
            print(f"Expected Hash: {expected_hash}")
            print(f"Generated Hash: {generated_hash}")
            print(f"Match: {is_correct}")
            print("="*40)
            sys.exit(1)
