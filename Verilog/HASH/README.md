# HASH

## MD5
This is a Verilog implementation of the MD5 (Message-Digest Algorithm 5) hash function. The module takes in 512-bit data blocks (`part_in`) and computes a 128-bit MD5 hash output. It operates synchronously with a clock signal (`clk`) and includes flow control signals for handling the processing of multiple data blocks.

### Inputs
- **`clk`**: Clock signal (synchronous). The module processes data on the rising edge of this clock.
- **`reset`**: Reset signal. When asserted, it resets the internal state of the MD5 hash computation.
- **`part_in` [511:0]**: The input data block. This is a 512-bit block of data to be processed.
- **`part_in_ready`**: Indicates that `part_in` is ready to be processed. The module reads the data from `part_in` when this signal is asserted.
- **`total_data_length` [63:0]**: The total length of the data (in bits) being hashed. This is used to handle padding and ensure correct hash output.

### Outputs
- **`hash` [127:0]**: The final 128-bit MD5 digest. This output becomes valid when the full data has been processed.
- **`ready_for_next_part`**: Indicates that the module is ready to receive the next 512-bit block of data for hashing. This signal is asserted after the current block has been processed.
- **`digest_valid`**: Asserted when the final 128-bit hash has been computed and is available at the `hash` output.
