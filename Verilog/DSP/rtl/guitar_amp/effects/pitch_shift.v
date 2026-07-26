// Pitch Shift — Granular time-domain pitch shifter
// Uses two overlapping grains with crossfade to shift pitch without changing tempo
// Range: -12 to +12 semitones

module pitch_shift #(
    parameter DATA_WIDTH      = 24,
    parameter GRAIN_SIZE      = 1024,   // Grain length in samples (~21ms @ 48kHz)
    parameter BUFFER_SIZE     = 4096,   // Circular buffer size (must be power of 2)
    parameter CROSSFADE_LEN   = 128     // Crossfade overlap in samples
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast,

    // Controls
    input  wire signed [7:0]             shift,     // Pitch shift: -128=-12st, 0=unity, +127=+12st
    input  wire [7:0]                    mix,       // Wet/dry mix (0=dry, 255=wet)
    input  wire [7:0]                    grain_size_ctrl  // Grain size adjust (affects quality/latency tradeoff)
);

    localparam ADDR_WIDTH = $clog2(BUFFER_SIZE);

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // Circular buffer
    reg signed [DATA_WIDTH-1:0] buffer [0:BUFFER_SIZE-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // Two read pointers (grains) with fractional precision for non-integer rates
    reg [ADDR_WIDTH+15:0] rd_ptr_a;  // 16 fractional bits
    reg [ADDR_WIDTH+15:0] rd_ptr_b;  // 16 fractional bits

    // Grain phase counters
    reg [$clog2(GRAIN_SIZE):0] grain_counter_a;
    reg [$clog2(GRAIN_SIZE):0] grain_counter_b;

    // Read rate: shift > 0 means read faster (pitch up), < 0 means read slower (pitch down)
    // rate = 1.0 + shift/128 * range, where range maps to ±1 octave
    // In fixed-point 16-bit fractional: 65536 = 1.0x playback rate
    // Pitch up by 1 octave = rate 2.0 = 131072
    // Pitch down by 1 octave = rate 0.5 = 32768
    wire signed [16:0] shift_ext = {{9{shift[7]}}, shift};
    wire [16:0] rate_offset = (shift_ext * 17'sd512) >>> 7;  // scale shift to rate
    wire [16:0] read_rate = 17'd65536 + rate_offset;         // 1.0 + offset

    // Effective grain size
    wire [$clog2(GRAIN_SIZE):0] eff_grain = GRAIN_SIZE;
    wire [$clog2(GRAIN_SIZE):0] half_grain = eff_grain >> 1;

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr_a <= 0;
            rd_ptr_b <= {half_grain, 16'd0};  // Start B half a grain offset
            grain_counter_a <= 0;
            grain_counter_b <= half_grain;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // Write input to circular buffer
                buffer[wr_ptr] <= s_axis_tdata;
                wr_ptr <= wr_ptr + 1;

                // Advance read pointers at pitch-shifted rate
                rd_ptr_a <= rd_ptr_a + read_rate;
                rd_ptr_b <= rd_ptr_b + read_rate;

                // Advance grain counters
                grain_counter_a <= (grain_counter_a >= eff_grain - 1) ? 0 : grain_counter_a + 1;
                grain_counter_b <= (grain_counter_b >= eff_grain - 1) ? 0 : grain_counter_b + 1;

                // Reset read pointers at grain boundaries to prevent drift
                if (grain_counter_a == 0)
                    rd_ptr_a <= {wr_ptr - eff_grain[$clog2(GRAIN_SIZE):0], 16'd0};
                if (grain_counter_b == 0)
                    rd_ptr_b <= {wr_ptr - eff_grain[$clog2(GRAIN_SIZE):0], 16'd0};

                // Read from buffer (integer part of fractional pointers)
                wire [ADDR_WIDTH-1:0] addr_a = rd_ptr_a[ADDR_WIDTH+15:16];
                wire [ADDR_WIDTH-1:0] addr_b = rd_ptr_b[ADDR_WIDTH+15:16];
                reg signed [DATA_WIDTH-1:0] sample_a, sample_b;
                sample_a = buffer[addr_a];
                sample_b = buffer[addr_b];

                // Compute crossfade windows (triangular for each grain)
                reg [7:0] window_a, window_b;
                if (grain_counter_a < CROSSFADE_LEN)
                    window_a = (grain_counter_a * 255) / CROSSFADE_LEN;
                else if (grain_counter_a > eff_grain - CROSSFADE_LEN)
                    window_a = ((eff_grain - grain_counter_a) * 255) / CROSSFADE_LEN;
                else
                    window_a = 8'd255;

                if (grain_counter_b < CROSSFADE_LEN)
                    window_b = (grain_counter_b * 255) / CROSSFADE_LEN;
                else if (grain_counter_b > eff_grain - CROSSFADE_LEN)
                    window_b = ((eff_grain - grain_counter_b) * 255) / CROSSFADE_LEN;
                else
                    window_b = 8'd255;

                // Mix grains
                reg signed [DATA_WIDTH+7:0] grain_mixed;
                grain_mixed = (sample_a * $signed({1'b0, window_a}) +
                              sample_b * $signed({1'b0, window_b})) >>> 8;

                // Wet/dry mix
                reg signed [DATA_WIDTH+7:0] wet_dry;
                wet_dry = (grain_mixed[DATA_WIDTH-1:0] * $signed({1'b0, mix}) +
                          s_axis_tdata * $signed({1'b0, (8'd255 - mix)})) >>> 8;

                m_axis_tdata <= wet_dry[DATA_WIDTH-1:0];
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
