// Tremolo — Amplitude modulation via LFO
// Modulates signal volume with selectable waveform shape

module tremolo #(
    parameter DATA_WIDTH = 24,
    parameter LFO_WIDTH  = 32
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
    input  wire [7:0]                    rate,      // LFO speed
    input  wire [7:0]                    depth,     // Modulation depth (0=none, 255=full)
    input  wire [1:0]                    shape      // 0=sine, 1=triangle, 2=square, 3=saw
);

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // LFO phase accumulator
    reg [LFO_WIDTH-1:0] lfo_phase;
    wire [LFO_WIDTH-1:0] lfo_incr = {rate, {(LFO_WIDTH-16){1'b0}}};  // Scale rate to phase increment

    always @(posedge clk) begin
        if (rst)
            lfo_phase <= 0;
        else if (s_axis_tvalid && s_axis_tready)
            lfo_phase <= lfo_phase + lfo_incr;
    end

    // LFO waveform generation (output range: 0 to 255)
    reg [7:0] lfo_value;

    wire [7:0] phase_msb = lfo_phase[LFO_WIDTH-1:LFO_WIDTH-8];

    always @(*) begin
        case (shape)
            2'd0: begin  // Sine approximation (quadratic)
                reg [7:0] half_phase;
                reg [15:0] parabola;
                half_phase = phase_msb[6:0] << 1;
                parabola = half_phase * (8'd255 - half_phase);
                lfo_value = phase_msb[7] ? 8'd128 - parabola[15:9] : 8'd128 + parabola[15:9];
            end
            2'd1: begin  // Triangle
                lfo_value = phase_msb[7] ? ~{phase_msb[6:0], 1'b0} : {phase_msb[6:0], 1'b0};
            end
            2'd2: begin  // Square
                lfo_value = phase_msb[7] ? 8'd0 : 8'd255;
            end
            2'd3: begin  // Sawtooth
                lfo_value = phase_msb;
            end
        endcase
    end

    // Apply modulation
    // gain = 255 - depth + (lfo_value * depth / 256)
    // This ensures gain ranges from (255-depth) to 255
    wire [15:0] mod_amount = lfo_value * depth;
    wire [7:0] gain = (8'd255 - depth) + mod_amount[15:8];

    always @(posedge clk) begin
        if (rst) begin
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                reg signed [DATA_WIDTH+7:0] scaled;
                scaled = s_axis_tdata * $signed({1'b0, gain});
                m_axis_tdata <= scaled >>> 8;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
