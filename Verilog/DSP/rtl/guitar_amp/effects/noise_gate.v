// Noise Gate — Silences signal below threshold
// State machine: CLOSED -> ATTACK -> OPEN -> HOLD -> RELEASE -> CLOSED

module noise_gate #(
    parameter DATA_WIDTH    = 24,
    parameter ENV_WIDTH     = 32,
    parameter HYSTERESIS_DB = 6,
    parameter HOLD_SAMPLES  = 2400,   // 50ms at 48kHz
    parameter ATTACK_COEFF  = 16,
    parameter RELEASE_COEFF = 16,
    parameter RANGE_DB      = 80
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

    // Control
    input  wire [7:0]                    open_threshold,   // Level to open gate
    input  wire [7:0]                    close_threshold,  // Level to close (lower = hysteresis)
    input  wire [15:0]                   hold_time         // Hold time in samples
);

    // Gate states
    localparam ST_CLOSED  = 3'd0;
    localparam ST_ATTACK  = 3'd1;
    localparam ST_OPEN    = 3'd2;
    localparam ST_HOLD    = 3'd3;
    localparam ST_RELEASE = 3'd4;

    reg [2:0] state;
    reg [15:0] hold_counter;
    reg [7:0] gate_gain;  // 0 = closed, 255 = open

    // Envelope follower
    reg [ENV_WIDTH-1:0] envelope;
    wire [DATA_WIDTH-1:0] abs_input = s_axis_tdata[DATA_WIDTH-1] ? -s_axis_tdata : s_axis_tdata;

    // Threshold comparisons
    wire [ENV_WIDTH-1:0] open_level  = {{(ENV_WIDTH-8){1'b0}}, open_threshold} << (DATA_WIDTH - 10);
    wire [ENV_WIDTH-1:0] close_level = {{(ENV_WIDTH-8){1'b0}}, close_threshold} << (DATA_WIDTH - 10);

    // Working registers
    reg [ENV_WIDTH-1:0] input_level;
    reg signed [DATA_WIDTH+7:0] gated;

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_CLOSED;
            hold_counter <= 0;
            gate_gain <= 0;
            envelope <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            if (s_axis_tvalid && s_axis_tready) begin
                // Envelope follower (peak detection with fast attack, slow release)
                input_level = {{(ENV_WIDTH-DATA_WIDTH){1'b0}}, abs_input};

                if (input_level > envelope)
                    envelope <= envelope + ((input_level - envelope) >> 2);  // Fast attack
                else
                    envelope <= envelope - ((envelope - input_level) >> 6);  // Slow release

                // State machine
                case (state)
                    ST_CLOSED: begin
                        gate_gain <= 0;
                        if (envelope > open_level)
                            state <= ST_ATTACK;
                    end

                    ST_ATTACK: begin
                        // Ramp gain up quickly
                        if (gate_gain < 8'd240)
                            gate_gain <= gate_gain + 8'd16;
                        else begin
                            gate_gain <= 8'd255;
                            state <= ST_OPEN;
                        end
                    end

                    ST_OPEN: begin
                        gate_gain <= 8'd255;
                        if (envelope < close_level) begin
                            state <= ST_HOLD;
                            hold_counter <= 0;
                        end
                    end

                    ST_HOLD: begin
                        gate_gain <= 8'd255;
                        if (envelope > open_level) begin
                            state <= ST_OPEN;
                        end else if (hold_counter >= hold_time) begin
                            state <= ST_RELEASE;
                        end else begin
                            hold_counter <= hold_counter + 1;
                        end
                    end

                    ST_RELEASE: begin
                        // Ramp gain down slowly
                        if (envelope > open_level) begin
                            state <= ST_ATTACK;
                        end else if (gate_gain > 8'd4) begin
                            gate_gain <= gate_gain - 8'd4;
                        end else begin
                            gate_gain <= 0;
                            state <= ST_CLOSED;
                        end
                    end

                    default: state <= ST_CLOSED;
                endcase

                // Apply gate gain
                gated = s_axis_tdata * $signed({1'b0, gate_gain});
                m_axis_tdata <= gated >>> 8;
                m_axis_tvalid <= 1;
                m_axis_tlast <= s_axis_tlast;
            end
        end
    end

endmodule
