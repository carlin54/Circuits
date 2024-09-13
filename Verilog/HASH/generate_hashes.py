#!/usr/bin/python3

import hashlib
import random

def generate_random_hex_string(byte_length):
    """Generates a random hex string of the given byte length."""
    if byte_length == 0:
        return ''

    hex_string = ''.join(format(random.randint(0, 255), '02x') for _ in range(byte_length))

    return hex_string

def md5_hash_hex(hex_string):
    """Computes the MD5 hash of the hex string."""
    byte_data = bytes.fromhex(hex_string)
    md5_hash = hashlib.md5(byte_data).hexdigest()
    return md5_hash

if __name__ == "__main__":
    # Generate hashes of 0 bytes to num blocks *
    output_lines = []

    num_blocks = 4
    for byte_length in range(0, (num_blocks*64)+1):
        for _ in range(10):
            input_hex = generate_random_hex_string(byte_length)
            generated_hash = md5_hash_hex(input_hex)
            padded_input_hex = input_hex.ljust(128*num_blocks, '0')
            output_lines.append(f"{padded_input_hex} {8*byte_length} {generated_hash}")

    unique_lines = list(dict.fromkeys(output_lines))

    # Write the hashes out to file
    with open("md5_hashes.txt", 'w') as f:
        for line in unique_lines:
            f.write(line + "\n")
