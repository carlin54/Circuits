// I2S Transmitter — Serializes audio data to DAC
// Generates BCLK and LRCLK from system clock, outputs serial data

module i2s_transmitter #(
    parameter DATA_WIDTH    = 24,
    parameter NUM_CHANNELS  = 2,
    parameter BIT_ORDER     = "MSB_FIRST",
    parameter JUSTIFICATION = "I2S",
    parameter MCLK_DIVIDE   = 8,     // System clock / MCLK_DIVIDE = BCLK
    parameter LRCLK_DIVIDE  = 64     // BCLK / LRCLK_DIVIDE = sample rate (per channel)
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output reg                           s_axis_tready,
    input  wire                          s_axis_tlast,

    // I2S output
    output reg                           mclk,
    output reg                           bclk,
    output reg                           lrclk,
    output reg                           sdata
);

    localparam BCLK_HALF = MCLK_DIVIDE / 2;
    localparam LRCLK_HALF = LRCLK_DIVIDE / 2;

    // Clock dividers
    reg [$clog2(MCLK_DIVIDE)-1:0] bclk_cnt;
    reg [$clog2(LRCLK_DIVIDE)-1:0] lr_cnt;

    // Shift register
    reg [DATA_WIDTH-1:0] shift_reg;
    reg [5:0] bit_cnt;
    reg channel;  // 0=left, 1=right

    // Double buffer
    reg signed [DATA_WIDTH-1:0] sample_buf_l;
    reg signed [DATA_WIDTH-1:0] sample_buf_r;
    reg buf_l_valid, buf_r_valid;

    // State
    reg transmitting;
    reg bclk_rise;
    reg [5:0] skip_cnt;

    // MCLK generation (system_clk / 2)
    reg [$clog2(MCLK_DIVIDE/2)-1:0] mclk_cnt;
    always @(posedge clk) begin
        if (rst) begin
            mclk <= 0;
            mclk_cnt <= 0;
        end else begin
            if (mclk_cnt == (MCLK_DIVIDE/4) - 1) begin
                mclk <= ~mclk;
                mclk_cnt <= 0;
            end else begin
                mclk_cnt <= mclk_cnt + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            bclk <= 0;
            lrclk <= 0;
            sdata <= 0;
            bclk_cnt <= 0;
            lr_cnt <= 0;
            bit_cnt <= 0;
            channel <= 0;
            shift_reg <= 0;
            transmitting <= 0;
            bclk_rise <= 0;
            skip_cnt <= 0;
            s_axis_tready <= 0;
            sample_buf_l <= 0;
            sample_buf_r <= 0;
            buf_l_valid <= 0;
            buf_r_valid <= 0;
        end else begin
            bclk_rise <= 0;
            s_axis_tready <= 0;

            // Accept samples into double buffer
            if (s_axis_tvalid && !buf_l_valid) begin
                sample_buf_l <= s_axis_tdata;
                buf_l_valid <= 1;
                s_axis_tready <= 1;
            end else if (s_axis_tvalid && buf_l_valid && !buf_r_valid) begin
                sample_buf_r <= s_axis_tdata;
                buf_r_valid <= 1;
                s_axis_tready <= 1;
            end

            // Generate BCLK
            if (bclk_cnt == BCLK_HALF - 1) begin
                bclk <= ~bclk;
                bclk_cnt <= 0;
                if (!bclk) bclk_rise <= 1;  // Rising edge
            end else begin
                bclk_cnt <= bclk_cnt + 1;
            end

            // LRCLK and frame control
            if (bclk_rise) begin
                lr_cnt <= lr_cnt + 1;

                if (lr_cnt == LRCLK_HALF - 1) begin
                    lrclk <= ~lrclk;
                    bit_cnt <= 0;
                    channel <= lrclk;  // Channel that's about to start

                    // Load new sample
                    if (!lrclk) begin
                        // Starting left channel
                        if (buf_l_valid) begin
                            shift_reg <= buf_l_valid ? sample_buf_l : 0;
                        end else begin
                            shift_reg <= 0;
                        end
                        transmitting <= 1;
                        if (JUSTIFICATION == "I2S")
                            skip_cnt <= 1;
                        else
                            skip_cnt <= 0;
                    end else begin
                        // Starting right channel
                        shift_reg <= buf_r_valid ? sample_buf_r : 0;
                        transmitting <= 1;
                        if (JUSTIFICATION == "I2S")
                            skip_cnt <= 1;
                        else
                            skip_cnt <= 0;
                        // Clear buffers for next frame
                        buf_l_valid <= 0;
                        buf_r_valid <= 0;
                    end
                end

                if (lr_cnt == LRCLK_DIVIDE - 1)
                    lr_cnt <= 0;

                // Shift out data on falling BCLK (data changes, sampled on rise by DAC)
                if (transmitting) begin
                    if (skip_cnt > 0) begin
                        skip_cnt <= skip_cnt - 1;
                        sdata <= 0;
                    end else if (bit_cnt < DATA_WIDTH) begin
                        if (BIT_ORDER == "MSB_FIRST") begin
                            sdata <= shift_reg[DATA_WIDTH-1];
                            shift_reg <= {shift_reg[DATA_WIDTH-2:0], 1'b0};
                        end else begin
                            sdata <= shift_reg[0];
                            shift_reg <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
                        end
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        sdata <= 0;
                    end
                end
            end
        end
    end

endmodule
