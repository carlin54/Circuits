// IIR Biquad Filter — Direct Form II Transposed (DF2T)
// Cascadable second-order sections with runtime coefficient reload
// Transfer function per section: H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)

module iir_biquad #(
    parameter DATA_WIDTH     = 24,
    parameter COEFF_WIDTH    = 18,
    parameter INTERNAL_WIDTH = 40,
    parameter FRAC_BITS      = 16,
    parameter NUM_SECTIONS   = 1,
    parameter COEFF_RELOAD   = 1,
    parameter FORM           = "DF2T"  // "DF1", "DF2", "DF2T"
)(
    input  wire                         clk,
    input  wire                         rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,

    // AXI-Stream output
    output wire signed [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast,

    // Coefficient reload interface
    input  wire                              coeff_we,
    input  wire [2:0]                        coeff_addr,   // 0=b0, 1=b1, 2=b2, 3=a1, 4=a2
    input  wire signed [COEFF_WIDTH-1:0]     coeff_data,
    input  wire [$clog2(NUM_SECTIONS)-1:0]   coeff_section
);

    // Coefficient storage: 5 coefficients per section
    reg signed [COEFF_WIDTH-1:0] b0 [0:NUM_SECTIONS-1];
    reg signed [COEFF_WIDTH-1:0] b1 [0:NUM_SECTIONS-1];
    reg signed [COEFF_WIDTH-1:0] b2 [0:NUM_SECTIONS-1];
    reg signed [COEFF_WIDTH-1:0] a1 [0:NUM_SECTIONS-1];
    reg signed [COEFF_WIDTH-1:0] a2 [0:NUM_SECTIONS-1];

    // State variables: 2 per section (DF2T)
    reg signed [INTERNAL_WIDTH-1:0] w1 [0:NUM_SECTIONS-1];
    reg signed [INTERNAL_WIDTH-1:0] w2 [0:NUM_SECTIONS-1];

    // Pipeline signals
    reg signed [DATA_WIDTH-1:0] section_input [0:NUM_SECTIONS];
    reg [NUM_SECTIONS:0] valid_pipe;
    reg [NUM_SECTIONS:0] last_pipe;

    // Flow control
    reg busy;
    reg [$clog2(NUM_SECTIONS):0] stage;

    assign s_axis_tready = !busy && m_axis_tready;
    assign m_axis_tdata  = section_input[NUM_SECTIONS];
    assign m_axis_tvalid = valid_pipe[NUM_SECTIONS];
    assign m_axis_tlast  = last_pipe[NUM_SECTIONS];

    // Coefficient reload
    generate
        if (COEFF_RELOAD) begin : gen_coeff_reload
            always @(posedge clk) begin
                if (coeff_we) begin
                    case (coeff_addr)
                        3'd0: b0[coeff_section] <= coeff_data;
                        3'd1: b1[coeff_section] <= coeff_data;
                        3'd2: b2[coeff_section] <= coeff_data;
                        3'd3: a1[coeff_section] <= coeff_data;
                        3'd4: a2[coeff_section] <= coeff_data;
                        default: ;
                    endcase
                end
            end
        end
    endgenerate

    // Initialize coefficients to unity (b0=1, rest=0)
    integer init_i;
    initial begin
        for (init_i = 0; init_i < NUM_SECTIONS; init_i = init_i + 1) begin
            b0[init_i] = (1 << FRAC_BITS);  // 1.0 in fixed-point
            b1[init_i] = 0;
            b2[init_i] = 0;
            a1[init_i] = 0;
            a2[init_i] = 0;
            w1[init_i] = 0;
            w2[init_i] = 0;
        end
    end

    // DF2T processing: pipelined, one section per clock
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            stage <= 0;
            valid_pipe <= 0;
            last_pipe <= 0;
            for (init_i = 0; init_i < NUM_SECTIONS; init_i = init_i + 1) begin
                w1[init_i] <= 0;
                w2[init_i] <= 0;
                section_input[init_i] <= 0;
            end
            section_input[NUM_SECTIONS] <= 0;
        end else begin
            if (!busy && s_axis_tvalid && s_axis_tready) begin
                // Latch input, start processing
                section_input[0] <= s_axis_tdata;
                valid_pipe[0] <= 1;
                last_pipe[0] <= s_axis_tlast;
                busy <= 1;
                stage <= 0;
            end

            if (busy) begin
                // Process one section per clock
                if (stage < NUM_SECTIONS) begin
                    // DF2T equations:
                    // y[n] = b0*x[n] + w1[n-1]
                    // w1[n] = b1*x[n] - a1*y[n] + w2[n-1]
                    // w2[n] = b2*x[n] - a2*y[n]

                    // Compute products (full precision)
                    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] prod_b0;
                    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] prod_b1;
                    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] prod_b2;
                    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] prod_a1;
                    reg signed [DATA_WIDTH+COEFF_WIDTH-1:0] prod_a2;
                    reg signed [INTERNAL_WIDTH-1:0] y_internal;
                    reg signed [INTERNAL_WIDTH-1:0] new_w1;
                    reg signed [INTERNAL_WIDTH-1:0] new_w2;

                    prod_b0 = section_input[stage] * b0[stage];
                    prod_b1 = section_input[stage] * b1[stage];
                    prod_b2 = section_input[stage] * b2[stage];

                    // y = b0*x + w1
                    y_internal = (prod_b0 >>> FRAC_BITS) + w1[stage];

                    // Saturate output
                    if (y_internal > ((1 << (DATA_WIDTH-1)) - 1))
                        section_input[stage+1] <= (1 << (DATA_WIDTH-1)) - 1;
                    else if (y_internal < -(1 << (DATA_WIDTH-1)))
                        section_input[stage+1] <= -(1 << (DATA_WIDTH-1));
                    else
                        section_input[stage+1] <= y_internal[DATA_WIDTH-1:0];

                    // Update state using saturated output for feedback
                    prod_a1 = y_internal[DATA_WIDTH-1:0] * a1[stage];
                    prod_a2 = y_internal[DATA_WIDTH-1:0] * a2[stage];

                    new_w1 = (prod_b1 >>> FRAC_BITS) - (prod_a1 >>> FRAC_BITS) + w2[stage];
                    new_w2 = (prod_b2 >>> FRAC_BITS) - (prod_a2 >>> FRAC_BITS);

                    w1[stage] <= new_w1;
                    w2[stage] <= new_w2;

                    valid_pipe[stage+1] <= valid_pipe[stage];
                    last_pipe[stage+1] <= last_pipe[stage];
                    stage <= stage + 1;
                end else begin
                    busy <= 0;
                end
            end else begin
                // Clear valid when consumed
                if (m_axis_tvalid && m_axis_tready)
                    valid_pipe[NUM_SECTIONS] <= 0;
            end
        end
    end

endmodule
