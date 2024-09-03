#!/usr/bin/python3

import hashlib
import random

def generate_random_hex_string(bit_length):
    """Generates a random hex string of the given bit length."""
    if bit_length == 0:
        return ''  # Return an empty string for 0-bit input

    # Calculate the number of full bytes required
    byte_length = (bit_length + 7) // 8  # Round up to the nearest byte

    # Generate a random string where each byte is a random value between 0x00 and 0xFF
    hex_string = ''.join(format(random.randint(0, 255), '02x') for _ in range(byte_length))

    # If the bit length is not a multiple of 8, truncate the last byte to match the bit length
    if bit_length % 8 != 0:
        remaining_bits = bit_length % 8
        last_byte = int(hex_string[-2:], 16) & (0xFF << (8 - remaining_bits))
        hex_string = hex_string[:-2] + format(last_byte, '02x')

    return hex_string

def md5_hash_hex(hex_string):
    """Computes the MD5 hash of the hex string."""
    byte_data = bytes.fromhex(hex_string)
    md5_hash = hashlib.md5(byte_data).hexdigest()
    return md5_hash

if __name__ == "__main__":
    output_lines = []

    # Prepare the output lines
    for bit_length in range(0, 513):
        for _ in range(10):
            # Generate random data with the specified bit length
            input_hex = generate_random_hex_string(bit_length)

            # Compute the MD5 hash based on the actual data (excluding padding zeros)
            generated_hash = md5_hash_hex(input_hex)

            # Pad the string with zeros to ensure it's 512 bits (128 hex characters)
            padded_input_hex = input_hex.ljust(128, '0')

            # Add the line to the output list
            output_lines.append(f"{padded_input_hex} {bit_length} {generated_hash}")

    # Remove duplicate lines
    unique_lines = list(dict.fromkeys(output_lines))

    # Write the final list to the output file
    with open("md5_hashes.txt", 'w') as f:
        for line in unique_lines:
            f.write(line + "\n")
