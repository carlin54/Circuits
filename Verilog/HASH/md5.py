#!/usr/bin/python3

import struct
import math
import sys

# Define constants
S = [7, 12, 17, 22] * 4 + [5, 9, 14, 20] * 4 + [4, 11, 16, 23] * 4 + [6, 10, 15, 21] * 4
K = [int(abs(math.sin(i + 1)) * 2**32) for i in range(64)]

# Define auxiliary functions
F = lambda x, y, z: (x & y) | (~x & z)
G = lambda x, y, z: (x & z) | (y & ~z)
H = lambda x, y, z: x ^ y ^ z
I = lambda x, y, z: y ^ (x | ~z)

def left_rotate(x, c):
    return (x << c) | (x >> (32 - c))

# Padding the message to make its length congruent to 448 mod 512
def md5_padding(message):
    message_len_in_bits = len(message) * 8
    padding = b'\x80' + b'\x00' * ((56 - (len(message) + 1) % 64) % 64)
    return message + padding + struct.pack('<Q', message_len_in_bits)

# Process the message in successive 512-bit chunks
def md5_process_chunk(chunk, state):
    A, B, C, D = state

    #chunk = b'\x00' * 64  # 64 bytes to match the 16 * 4 bytes of '<16I'
    X = list(struct.unpack('<16I', chunk))
    bit_vector = ''.join(f'{x:032b}' for x in X[::-1])
    print(f"X = {bit_vector}")

    for i in range(16):
        print(''.join(f'{x:032b}' for x in X))

    def print_hash():
        digest = struct.pack('<4I', A, B, C, D)
        print(''.join(f'{byte:02x}' for byte in digest))

    # Save original values of A, B, C, D
    original_A, original_B, original_C, original_D = A, B, C, D

    # Round 1
    for i in range(16):
        print("A")
        print(f"{A:08x}")
        print("A + F(B, C, D)")
        print(f"{A + F(B, C, D):08x}")
        print("A + F(B, C, D) + X[i]")
        print(f"{A + F(B, C, D) + X[i]:08x}")
        print(f"X[i] = {X[i]}")
        print(f"X[i] = {X[i]:032b}")
        value = X[i]
        little_endian_value = struct.unpack('<I', struct.pack('>I', value))[0]
        print(f"Xlittle[i] = {little_endian_value:#010x}")
        print("((A + F(B, C, D) + X[i] + K[i]))")
        print(f"{(A + F(B, C, D) + X[i] + K[i]):08x}")
        print("((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF)")
        print(f"{(A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF:08x}")
        print("(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i]))")
        print(f"{(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])):08x}")
        print("(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF")
        print(f"{(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF:08x}")
        A = (B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        print_hash()
        print(f"B_reg:{B:08x}")
        print(f"S:{S[i]}, X[i]:{X[i]}, K[i]:{K[i]:08x}, A:{A:08x}, B:{B:08x}, C:{C:08x}, D:{D:08x}")
        #print(f"After Round 1, Operation {i + 1}, S = {S[i]}, K[i] = {K[i]:08x}: A = {A:08x}, B = {B:08x}, C = {C:08x}, D = {D:08x}")

    # Round 2
    for i in range(16, 32):
        A = (B + left_rotate((A + G(B, C, D) + X[(5 * i + 1) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        #print(f"After Round 2, Operation {i - 15}: A = {A:08x}, B = {B:08x}, C = {C:08x}, D = {D:08x}")
        print_hash()
        print(f"B_reg:{B:08x}")

    # Round 3
    for i in range(32, 48):
        A = (B + left_rotate((A + H(B, C, D) + X[(3 * i + 5) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        #print(f"After Round 3, Operation {i - 31}: A = {A:08x}, B = {B:08x}, C = {C:08x}, D = {D:08x}")
        print_hash()
        print(f"B_reg:{B:08x}")

    # Round 4
    for i in range(48, 64):
        """
        print("A")
        print(f"{A:08x}")
        print("A + F(B, C, D)")
        print(f"{A + F(B, C, D):08x}")
        print("A + F(B, C, D) + X[i]")
        print(f"{A + F(B, C, D) + X[i]:08x}")
        print(f"X[i] = {X[i]}")
        print("((A + F(B, C, D) + X[i] + K[i]))")
        print(f"{(A + F(B, C, D) + X[i] + K[i]):08x}")
        print("((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF)")
        print(f"{(A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF:08x}")
        print("(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i]))")
        print(f"{(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])):08x}")
        print("(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF")
        print(f"{(B + left_rotate((A + F(B, C, D) + X[i] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF:08x}")
        """
        A = (B + left_rotate((A + I(B, C, D) + X[(7 * i) % 16] + K[i]) & 0xFFFFFFFF, S[i])) & 0xFFFFFFFF
        A, B, C, D = D, A, B, C
        print_hash()
        print(f"After Round 4, Operation {i - 47}: A = {A:08x}, B = {B:08x}, C = {C:08x}, D = {D:08x}")

    # Add this chunk's hash to result so far
    A = (A + original_A) & 0xFFFFFFFF
    B = (B + original_B) & 0xFFFFFFFF
    C = (C + original_C) & 0xFFFFFFFF
    D = (D + original_D) & 0xFFFFFFFF

    return A, B, C, D

# Main function to compute the MD5 hash
def md5(message):
    message = md5_padding(message)

    # Initialize variables:
    A = 0x67452301
    B = 0xefcdab89
    C = 0x98badcfe
    D = 0x10325476

    for i in range(0, len(message), 64):
        A, B, C, D = md5_process_chunk(message[i:i + 64], (A, B, C, D))


    # Output the final digest
    digest = struct.pack('<4I', A, B, C, D)
    return ''.join(f'{byte:02x}' for byte in digest)

# Test the implementation with an empty string (which corresponds to a block of zeros after padding)
print("MD5 ('') =", md5(b''))
