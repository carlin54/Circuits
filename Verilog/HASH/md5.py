#!/usr/bin/python3

import struct
import math
import sys

S = [7, 12, 17, 22] * 4 + [5, 9, 14, 20] * 4 + [4, 11, 16, 23] * 4 + [6, 10, 15, 21] * 4
K = [int(abs(math.sin(i + 1)) * 2**32) for i in range(64)]

F = lambda x, y, z: (x & y) | (~x & z)
G = lambda x, y, z: (x & z) | (y & ~z)
H = lambda x, y, z: x ^ y ^ z
I = lambda x, y, z: y ^ (x | ~z)

def left_rotate(x, c):
    return ((x << c) | (x >> (32 - c))) & 0xFFFFFFFF

def string_to_bit_vector(input_string):
    """Convert a string to a bit vector (list of 0s and 1s)."""
    bit_vector = []
    for char in input_string:
        # Convert each character to its ASCII value, then to an 8-bit binary string
        binary_representation = format(ord(char), '08b')
        # Append each bit (as an integer 0 or 1) to the bit vector
        bit_vector.extend(int(bit) for bit in binary_representation)
    return bit_vector

def md5_padding(bit_vector, original_length_in_bits):
    """Add MD5 padding to the bit vector."""
    bit_vector.append(1)

    while (len(bit_vector) % 512) != 448:
        bit_vector.append(0)

    original_length_bytes = struct.pack('<Q', original_length_in_bits)  # Little-endian 64-bit integer
    adds = []
    for byte in original_length_bytes:
        for i in range(7, -1, -1):  # MSB to LSB in each byte
            adds.append((byte >> i) & 1)

    bit_vector += adds

    print(f"adds: {adds}")

    return bit_vector

def bit_vector_to_bytes(bit_vector):
    """Convert a bit vector (list of bits) to a byte array."""
    byte_array = bytearray()
    for i in range(0, len(bit_vector), 8):
        byte = 0
        for bit in bit_vector[i:i+8]:
            byte = (byte << 1) | bit
        byte_array.append(byte)
    return bytes(byte_array)

def md5_process_chunk(chunk, state):
    A, B, C, D = state
    print(f"OutSS0: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")

    print(f"chunk:{chunk}")
    for c in chunk:
        print(f"c:{c:08b}")

    X = list(struct.unpack('<16I', chunk))
    for x in X:
        print(f"msg:{x:032b}")
        bit_1 = (x >> 1) & 1
        bit_30 = (x >> 30) & 1

    for i in range(16):
        print(f"Out S1: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        print(f"A_reg (before operation): {A:08x}")
        F_result = (B & C) | (~B & D)
        print(f"F_result: {F_result:08x}")

        # A_reg + F_result
        temp_A_F = (A + F_result) & 0xFFFFFFFF
        print(f"A_reg + F_result: {temp_A_F:08x}")

        # A_reg + F_result + X[i]
        temp_A_F_X = (temp_A_F + X[i]) & 0xFFFFFFFF
        print(f"A_reg + F_result + X[{i} % [16]: {temp_A_F_X:08x}")
        print(f"X[{i}]: {X[i]:032b}")

        # A_reg + F_result + X[i] + K[i]
        temp_A_F_X_K = (temp_A_F_X + K[i]) & 0xFFFFFFFF
        print(f"A_reg + F_result + X[{i} % 16] + K[{i}]: {temp_A_F_X_K:08x}")
        print(f"K[{i}]: {K[i]:08x}")

        # (A_reg + F_result + X[i] + K[i]) & 0xFFFFFFFF
        temp_sum = temp_A_F_X_K & 0xFFFFFFFF
        print(f"(A_reg + F_result + X[{i} % 16] + K[{i}]) & 0xFFFFFFFF: {temp_sum:08x}")

        # Left rotate the sum
        rotated_sum = left_rotate(temp_sum, S[i])
        print(f"left_rotate((A_reg + F_result + X[{i} % 16] + K[{i}]) & 0xFFFFFFFF, S[{i}]): {rotated_sum:08x}")
        print(f"S[{i}]: {S[i]}")

        # (B_reg + rotated_sum)
        temp_B_rotated = (B + rotated_sum) & 0xFFFFFFFF
        print(f"(B_reg + left_rotate(...)): {temp_B_rotated:08x}")

        A = (B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C

        print(f"Out E1: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        print("-" * 40)


    for i in range(16, 32):
        print(f"Out S2: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        A = (B + left_rotate((A + G(B, C, D) + X[(5 * i + 1) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        print(f"Out E2: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")


    for i in range(32, 48):
        print(f"Out S3: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        A = (B + left_rotate((A + H(B, C, D) + X[(3 * i + 5) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        print(f"Out E3: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")

    for i in range(48, 64):
        print(f"Out S4: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        A = (B + left_rotate((A + I(B, C, D) + X[(7 * i) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        print(f"Out E4: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")

    print(f"Out0S5: A:{state[0]:08x}, B:{state[1]:08x}, C:{state[2]:08x}, D:{state[3]:08x}")
    print(f"Out005: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
    A = (A + state[0]) & 0xFFFFFFFF
    B = (B + state[1]) & 0xFFFFFFFF
    C = (C + state[2]) & 0xFFFFFFFF
    D = (D + state[3]) & 0xFFFFFFFF
    print(f"OutEE5: A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
    return A, B, C, D

def md5(bv):
    bit_vector = list(bv)

    # Original length in bits
    original_length_in_bits = len(bit_vector)

    # Add MD5 padding
    bit_vector = md5_padding(bit_vector, original_length_in_bits)

    print("bit_vector:")
    print(bit_vector)
    print(len(bit_vector))

    # Convert bit vector to bytes
    message = bit_vector_to_bytes(bit_vector)

    print("message:")
    print(message)

    # Initialize MD5 variables
    A = 0x67452301
    B = 0xefcdab89
    C = 0x98badcfe
    D = 0x10325476

    # Process each 64-byte chunk of the message
    for i in range(0, len(message), 64):
        A, B, C, D = md5_process_chunk(message[i:i + 64], (A, B, C, D))

    # Output the final digest
    digest = struct.pack('<4I', A, B, C, D)
    return ''.join(f'{byte:02x}' for byte in digest)

def load_md5_hashes(file_path):
    """Loads the MD5 hashes and input data from the specified file."""
    hashes = []

    with open(file_path, 'r') as file:
        for line in file:
            line = line.strip()

            if line:  # Skip empty lines
                padded_input_hex, size_in_bits_str, expected_hash = line.split()

                size_in_bits = int(size_in_bits_str)

                padded_input_bits = list(hex_string_to_bit_vector(padded_input_hex))
                input_bits = padded_input_bits[:size_in_bits]

                hashes.append({
                    'input_bits': input_bits,
                    'size_in_bits': size_in_bits,
                    'expected_hash': expected_hash
                })

    return hashes


def hex_string_to_bit_vector(hex_string):
    """Converts a hex string to a bit vector (list of 0s and 1s)."""
    bit_vector = []

    # Convert each hex character to its binary representation and pad to 4 bits
    for hex_char in hex_string:
        binary_representation = format(int(hex_char, 16), '04b')
        bit_vector.extend(int(bit) for bit in binary_representation)

    return bit_vector


def test():
    assert md5(string_to_bit_vector('')) == 'd41d8cd98f00b204e9800998ecf8427e'
    assert md5(string_to_bit_vector('a')) == '0cc175b9c0f1b6a831c399e269772661'
    assert md5(string_to_bit_vector('abc')) == '900150983cd24fb0d6963f7d28e17f72'
    assert md5(string_to_bit_vector('message digest')) == 'f96b697d7cb7938d525a2f31aaf161d0'
    assert md5(string_to_bit_vector("abcdefghijklmnopqrstuvwxyz")) == "c3fcd3d76192e4007dfb496cca67e13b"
    assert md5(string_to_bit_vector("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")) == "d174ab98d277d9f5a5611c2c9f419d9f"
    assert md5(string_to_bit_vector("12345678901234567890123456789012345678901234567890123456789012345678901234567890")) == "57edf4a22be3c955ac49da2e2107b67a"

if __name__ == "__main__":
    #test()

    hashes = load_md5_hashes("md5_hashes.txt")
    for idx, d in enumerate(hashes):
        input_bits = d["input_bits"]
        size_in_bits = d["size_in_bits"]
        expected_hash = d["expected_hash"]
        print(f"{input_bits}, {len(input_bits)}, {expected_hash}")
        actual_hash = md5(input_bits)
        if actual_hash != expected_hash:
            print(f"input_bits: {input_bits}")
            print(f"size_in_bits: {size_in_bits}")
            print(f"expected_hash: {expected_hash}")
            print(f"actual_hash: {actual_hash}")
        else:
            print(f"passed: {actual_hash}")

        assert actual_hash == expected_hash
        sys.exit(1)

    print("All test cases passed!")
