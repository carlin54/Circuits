// I2S Receiver — Deserializes I2S audio from ADC
// Supports I2S, Left-Justified, and Right-Justified formats

module i2s_receiver #(
    parameter DATA_WIDTH    = 24,
    parameter NUM_CHANNELS  = 2,
    parameter BIT_ORDER     = "MSB_FIRST",
    parameter JUSTIFICATION = "I2S",
    parameter FIFO_DEPTH    = 4
)(
    // System clock domain
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream output (system clock domain)
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast,
    output reg                           m_axis_channel,  // 0=left, 1=right

    // I2S interface (audio clock domain)
    input  wire                          bclk,
    input  wire                          lrclk,
    input  wire                          sdata
);

    // Bit counter
    reg [5:0] bit_cnt;
    reg [DATA_WIDTH-1:0] shift_reg;
    reg lrclk_prev;
    reg lrclk_d1;
    reg bclk_prev;

    // Synchronizers for I2S signals into system clock domain
    reg [2:0] bclk_sync;
    reg [2:0] lrclk_sync;
    reg [2:0] sdata_sync;

    wire bclk_sys   = bclk_sync[2];
    wire lrclk_sys  = lrclk_sync[2];
    wire sdata_sys  = sdata_sync[2];

    // Edge detection
    wire bclk_rise  = bclk_sync[2] && !bclk_sync[1];
    wire bclk_fall  = !bclk_sync[2] && bclk_sync[1];
    wire lrclk_edge = lrclk_sync[2] ^ lrclk_d1;

    // I2S mode: data is valid on rising edge of BCLK
    // Data starts one BCLK after LRCLK transition (I2S format)
    reg sample_valid;
    reg [DATA_WIDTH-1:0] sample_data;
    reg sample_channel;

    // State
    reg receiving;
    reg [5:0] skip_bits;  // For right-justified mode

    always @(posedge clk) begin
        if (rst) begin
            bclk_sync <= 0;
            lrclk_sync <= 0;
            sdata_sync <= 0;
            lrclk_d1 <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            sample_valid <= 0;
            sample_data <= 0;
            sample_channel <= 0;
            receiving <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            m_axis_channel <= 0;
        end else begin
            // Synchronize I2S signals
            bclk_sync <= {bclk_sync[1:0], bclk};
            lrclk_sync <= {lrclk_sync[1:0], lrclk};
            sdata_sync <= {sdata_sync[1:0], sdata};
            lrclk_d1 <= lrclk_sync[2];

            sample_valid <= 0;

            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            // Detect LRCLK transitions (new sample boundary)
            if (lrclk_edge) begin
                // Output completed sample
                if (receiving && bit_cnt > 0) begin
                    sample_valid <= 1;
                    sample_data <= shift_reg;
                    sample_channel <= lrclk_d1;  // Previous channel
                end
                bit_cnt <= 0;
                shift_reg <= 0;
                receiving <= 0;

                if (JUSTIFICATION == "I2S")
                    skip_bits <= 1;  // Skip 1 BCLK for I2S format
                else if (JUSTIFICATION == "LEFT")
                    skip_bits <= 0;
                else
                    skip_bits <= 32 - DATA_WIDTH;  // Right justified
            end

            // Sample data on rising BCLK edge
            if (bclk_rise) begin
                if (skip_bits > 0) begin
                    skip_bits <= skip_bits - 1;
                end else if (bit_cnt < DATA_WIDTH) begin
                    receiving <= 1;
                    if (BIT_ORDER == "MSB_FIRST")
                        shift_reg <= {shift_reg[DATA_WIDTH-2:0], sdata_sys};
                    else
                        shift_reg <= {sdata_sys, shift_reg[DATA_WIDTH-1:1]};
                    bit_cnt <= bit_cnt + 1;
                end
            end

            // Output valid sample
            if (sample_valid) begin
                m_axis_tdata <= $signed(sample_data);
                m_axis_tvalid <= 1;
                m_axis_channel <= sample_channel;
                m_axis_tlast <= sample_channel;  // tlast at end of stereo pair
            end
        end
    end

endmodule
