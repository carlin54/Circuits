// Bit-Reversal Permutation for FFT
// Reorders input samples from natural order to bit-reversed order
// Uses a ping-pong buffer approach: write in natural order, read in bit-reversed order

module bit_reversal #(
    parameter N          = 1024,
    parameter DATA_WIDTH = 24
)(
    input  wire                         clk,
    input  wire                         rst,

    // Input (natural order)
    input  wire signed [DATA_WIDTH-1:0] data_re_in,
    input  wire signed [DATA_WIDTH-1:0] data_im_in,
    input  wire                         valid_in,
    input  wire                         last_in,
    output wire                         ready_in,

    // Output (bit-reversed order)
    output reg  signed [DATA_WIDTH-1:0] data_re_out,
    output reg  signed [DATA_WIDTH-1:0] data_im_out,
    output reg                          valid_out,
    output reg                          last_out,
    input  wire                         ready_out
);

    localparam LOG2_N = $clog2(N);
    localparam ADDR_WIDTH = LOG2_N;

    // Ping-pong buffers (real and imaginary)
    reg signed [DATA_WIDTH-1:0] buf_re [0:N-1];
    reg signed [DATA_WIDTH-1:0] buf_im [0:N-1];

    // State machine
    localparam ST_WRITE = 0;
    localparam ST_READ  = 1;

    reg state;
    reg [ADDR_WIDTH-1:0] wr_counter;
    reg [ADDR_WIDTH-1:0] rd_counter;

    assign ready_in = (state == ST_WRITE);

    // Bit-reverse function
    function [ADDR_WIDTH-1:0] bit_reverse;
        input [ADDR_WIDTH-1:0] addr;
        integer br_i;
        begin
            for (br_i = 0; br_i < ADDR_WIDTH; br_i = br_i + 1)
                bit_reverse[br_i] = addr[ADDR_WIDTH-1-br_i];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_WRITE;
            wr_counter <= 0;
            rd_counter <= 0;
            valid_out <= 0;
            last_out <= 0;
            data_re_out <= 0;
            data_im_out <= 0;
        end else begin
            case (state)
                ST_WRITE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        buf_re[wr_counter] <= data_re_in;
                        buf_im[wr_counter] <= data_im_in;

                        if (wr_counter == N - 1) begin
                            wr_counter <= 0;
                            state <= ST_READ;
                            rd_counter <= 0;
                        end else begin
                            wr_counter <= wr_counter + 1;
                        end
                    end
                end

                ST_READ: begin
                    if (ready_out || !valid_out) begin
                        data_re_out <= buf_re[bit_reverse(rd_counter)];
                        data_im_out <= buf_im[bit_reverse(rd_counter)];
                        valid_out <= 1;
                        last_out <= (rd_counter == N - 1);

                        if (rd_counter == N - 1) begin
                            rd_counter <= 0;
                            state <= ST_WRITE;
                        end else begin
                            rd_counter <= rd_counter + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
