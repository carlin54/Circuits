#!/usr/bin/python3

import os

data = [
    {"sv": 1, "tap1": 2, "tap2": 6, "chips": 0o1440},
    {"sv": 2, "tap1": 3, "tap2": 7, "chips": 0o1620},
    {"sv": 3, "tap1": 4, "tap2": 8, "chips": 0o1710},
    {"sv": 4, "tap1": 5, "tap2": 9, "chips": 0o1744},
    {"sv": 5, "tap1": 1, "tap2": 9, "chips": 0o1133},
    {"sv": 6, "tap1": 2, "tap2": 10, "chips": 0o1455},
    {"sv": 7, "tap1": 1, "tap2": 8, "chips": 0o1131},
    {"sv": 8, "tap1": 2, "tap2": 9, "chips": 0o1454},
    {"sv": 9, "tap1": 3, "tap2": 10, "chips": 0o1626},
    {"sv": 10, "tap1": 2, "tap2": 3, "chips": 0o1504},
    {"sv": 11, "tap1": 3, "tap2": 4, "chips": 0o1642},
    {"sv": 12, "tap1": 5, "tap2": 6, "chips": 0o1750},
    {"sv": 13, "tap1": 6, "tap2": 7, "chips": 0o1764},
    {"sv": 14, "tap1": 7, "tap2": 8, "chips": 0o1772},
    {"sv": 15, "tap1": 8, "tap2": 9, "chips": 0o1775},
    {"sv": 16, "tap1": 9, "tap2": 10, "chips": 0o1776},
    {"sv": 17, "tap1": 1, "tap2": 4, "chips": 0o1156},
    {"sv": 18, "tap1": 2, "tap2": 5, "chips": 0o1467},
    {"sv": 19, "tap1": 3, "tap2": 6, "chips": 0o1633},
    {"sv": 20, "tap1": 4, "tap2": 7, "chips": 0o1715},
    {"sv": 21, "tap1": 5, "tap2": 8, "chips": 0o1746},
    {"sv": 22, "tap1": 6, "tap2": 9, "chips": 0o1763},
    {"sv": 23, "tap1": 1, "tap2": 3, "chips": 0o1063},
    {"sv": 24, "tap1": 4, "tap2": 6, "chips": 0o1706},
    {"sv": 25, "tap1": 5, "tap2": 7, "chips": 0o1743},
    {"sv": 26, "tap1": 6, "tap2": 8, "chips": 0o1761},
    {"sv": 27, "tap1": 7, "tap2": 9, "chips": 0o1770},
    {"sv": 28, "tap1": 8, "tap2": 10, "chips": 0o1774},
    {"sv": 29, "tap1": 1, "tap2": 6, "chips": 0o1127},
    {"sv": 30, "tap1": 2, "tap2": 7, "chips": 0o1453},
    {"sv": 31, "tap1": 3, "tap2": 8, "chips": 0o1625},
    {"sv": 32, "tap1": 4, "tap2": 9, "chips": 0o1712},
]

tap1_file = "l1ca_generator_tap1.hex"
tap2_file = "l1ca_generator_tap2.hex"
chips_file = "l1ca_generator_octals.hex"

with open(tap1_file, "w") as f1, open(tap2_file, "w") as f2, open(chips_file, "w") as f3:
    for entry in data:
        f1.write(f"{entry['tap1']:02X}\n")
        f2.write(f"{entry['tap2']:02X}\n")
        f3.write(f"{entry['chips']:04X}\n")

print(f"Files generated:\n{tap1_file}\n{tap2_file}\n{chips_file}")
