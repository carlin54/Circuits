// FIR Filter — Parameterized structure (Direct, Transposed, Symmetric)
// Supports runtime coefficient reload and configurable multiply implementation

module fir_filter #(
    parameter DATA_WIDTH   = 24,
    parameter COEFF_WIDTH  = 16,
    parameter OUTPUT_WIDTH = 24,
    parameter NUM_TAPS     = 63,
    parameter FRAC_BITS    = 15,
    parameter STRUCTURE    = "TRANSPOSED",  // "DIRECT", "TRANSPOSED", "SYMMETRIC"
    parameter COEFF_RELOAD = 1,
    parameter COEFF_FILE   = "",
    parameter MULT_STYLE   = "DSP"  // "DSP", "FABRIC", "AUTO"
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output reg  signed [OUTPUT_WIDTH-1:0] m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast,

    // Coefficient reload interface
    input  wire                              coeff_we,
    input  wire [$clog2(NUM_TAPS)-1:0]       coeff_addr,
    input  wire signed [COEFF_WIDTH-1:0]     coeff_data
);

    // Coefficient storage
    reg signed [COEFF_WIDTH-1:0] coeffs [0:NUM_TAPS-1];

    // Internal accumulator width to avoid overflow
    localparam ACC_WIDTH = DATA_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS);

    // Flow control
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // Coefficient initialization
    integer ci;
    initial begin
        for (ci = 0; ci < NUM_TAPS; ci = ci + 1)
            coeffs[ci] = 0;
    end

    // Coefficient reload
    generate
        if (COEFF_RELOAD) begin : gen_reload
            always @(posedge clk) begin
                if (coeff_we)
                    coeffs[coeff_addr] <= coeff_data;
            end
        end else if (COEFF_FILE != "") begin : gen_rom
            initial $readmemh(COEFF_FILE, coeffs);
        end
    endgenerate

    // =========================================================================
    // TRANSPOSED FORM: Fully pipelined, 1 sample per clock, NUM_TAPS multipliers
    // =========================================================================
    generate
        if (STRUCTURE == "TRANSPOSED") begin : gen_transposed

            reg signed [ACC_WIDTH-1:0] tap_acc [0:NUM_TAPS-1];
            reg valid_d, last_d;
            reg signed [ACC_WIDTH-1:0] rounded_t;

            integer ti;
            always @(posedge clk) begin
                if (rst) begin
                    for (ti = 0; ti < NUM_TAPS; ti = ti + 1)
                        tap_acc[ti] <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tlast <= 0;
                    m_axis_tdata <= 0;
                    valid_d <= 0;
                    last_d <= 0;
                end else if (s_axis_tready) begin
                    valid_d <= s_axis_tvalid;
                    last_d <= s_axis_tlast;

                    if (s_axis_tvalid) begin
                        // First tap: multiply only
                        tap_acc[NUM_TAPS-1] <= s_axis_tdata * coeffs[NUM_TAPS-1];

                        // Middle taps: multiply + accumulate from next
                        for (ti = 1; ti < NUM_TAPS-1; ti = ti + 1)
                            tap_acc[ti] <= s_axis_tdata * coeffs[ti] + tap_acc[ti+1];

                        // Output tap: multiply + accumulate, then round to output width
                        tap_acc[0] <= s_axis_tdata * coeffs[0] + tap_acc[1];
                    end

                    // Output: take accumulator[0] rounded
                    m_axis_tvalid <= valid_d;
                    m_axis_tlast <= last_d;
                    if (valid_d) begin
                        // Round and saturate from ACC_WIDTH to OUTPUT_WIDTH
                        // Shift right by FRAC_BITS to align
                        rounded_t = tap_acc[0] + (1 << (FRAC_BITS - 1));  // Round half up
                        // Saturate
                        if (rounded_t[ACC_WIDTH-1:FRAC_BITS+OUTPUT_WIDTH-1] != {(ACC_WIDTH-FRAC_BITS-OUTPUT_WIDTH+1){rounded_t[ACC_WIDTH-1]}}) begin
                            m_axis_tdata <= rounded_t[ACC_WIDTH-1] ?
                                           {1'b1, {(OUTPUT_WIDTH-1){1'b0}}} :
                                           {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
                        end else begin
                            m_axis_tdata <= rounded_t[FRAC_BITS +: OUTPUT_WIDTH];
                        end
                    end
                end
            end

        end
    endgenerate

    // =========================================================================
    // DIRECT FORM: Uses delay line and MAC, NUM_TAPS clocks per sample
    // =========================================================================
    generate
        if (STRUCTURE == "DIRECT") begin : gen_direct

            reg signed [DATA_WIDTH-1:0] delay_line [0:NUM_TAPS-1];
            reg signed [ACC_WIDTH-1:0] accumulator;
            reg [$clog2(NUM_TAPS):0] tap_count;
            reg processing;
            reg last_saved;
            reg signed [ACC_WIDTH-1:0] final_acc;
            reg signed [ACC_WIDTH-1:0] rounded_d;

            integer di;
            always @(posedge clk) begin
                if (rst) begin
                    for (di = 0; di < NUM_TAPS; di = di + 1)
                        delay_line[di] <= 0;
                    accumulator <= 0;
                    tap_count <= 0;
                    processing <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tlast <= 0;
                    last_saved <= 0;
                end else begin
                    if (!processing) begin
                        if (s_axis_tvalid && s_axis_tready) begin
                            // Shift delay line
                            for (di = NUM_TAPS-1; di > 0; di = di - 1)
                                delay_line[di] <= delay_line[di-1];
                            delay_line[0] <= s_axis_tdata;
                            accumulator <= 0;
                            tap_count <= 0;
                            processing <= 1;
                            last_saved <= s_axis_tlast;
                            m_axis_tvalid <= 0;
                        end else begin
                            if (m_axis_tvalid && m_axis_tready)
                                m_axis_tvalid <= 0;
                        end
                    end else begin
                        // MAC: one tap per clock
                        accumulator <= accumulator + delay_line[tap_count] * coeffs[tap_count];
                        tap_count <= tap_count + 1;

                        if (tap_count == NUM_TAPS - 1) begin
                            processing <= 0;
                            // Output rounded result
                            final_acc = accumulator + delay_line[tap_count] * coeffs[tap_count];
                            rounded_d = final_acc + (1 << (FRAC_BITS - 1));

                            if (rounded_d[ACC_WIDTH-1:FRAC_BITS+OUTPUT_WIDTH-1] != {(ACC_WIDTH-FRAC_BITS-OUTPUT_WIDTH+1){rounded_d[ACC_WIDTH-1]}})
                                m_axis_tdata <= rounded_d[ACC_WIDTH-1] ?
                                               {1'b1, {(OUTPUT_WIDTH-1){1'b0}}} :
                                               {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
                            else
                                m_axis_tdata <= rounded_d[FRAC_BITS +: OUTPUT_WIDTH];

                            m_axis_tvalid <= 1;
                            m_axis_tlast <= last_saved;
                        end
                    end
                end
            end

            assign s_axis_tready = !processing && (m_axis_tready || !m_axis_tvalid);

        end
    endgenerate

    // =========================================================================
    // SYMMETRIC FORM: Exploits coefficient symmetry, NUM_TAPS/2 multipliers
    // =========================================================================
    generate
        if (STRUCTURE == "SYMMETRIC") begin : gen_symmetric

            localparam HALF_TAPS = (NUM_TAPS + 1) / 2;
            reg signed [DATA_WIDTH-1:0] delay_line [0:NUM_TAPS-1];
            reg signed [ACC_WIDTH-1:0] tap_acc [0:HALF_TAPS-1];
            reg valid_d, last_d;
            reg signed [DATA_WIDTH:0] pre_add;
            reg signed [ACC_WIDTH-1:0] sum_s;
            reg signed [ACC_WIDTH-1:0] rounded_s;

            integer si;
            always @(posedge clk) begin
                if (rst) begin
                    for (si = 0; si < NUM_TAPS; si = si + 1)
                        delay_line[si] <= 0;
                    for (si = 0; si < HALF_TAPS; si = si + 1)
                        tap_acc[si] <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tlast <= 0;
                    valid_d <= 0;
                    last_d <= 0;
                end else if (s_axis_tready) begin
                    valid_d <= s_axis_tvalid;
                    last_d <= s_axis_tlast;

                    if (s_axis_tvalid) begin
                        // Shift delay line
                        for (si = NUM_TAPS-1; si > 0; si = si - 1)
                            delay_line[si] <= delay_line[si-1];
                        delay_line[0] <= s_axis_tdata;

                        // Pre-add symmetric pairs, then multiply
                        for (si = 0; si < HALF_TAPS; si = si + 1) begin
                            if (si == NUM_TAPS - 1 - si) begin
                                // Center tap (odd-length filter)
                                tap_acc[si] <= delay_line[si] * coeffs[si];
                            end else begin
                                pre_add = delay_line[si] + delay_line[NUM_TAPS-1-si];
                                tap_acc[si] <= pre_add * coeffs[si];
                            end
                        end
                    end

                    // Sum all partial products
                    m_axis_tvalid <= valid_d;
                    m_axis_tlast <= last_d;
                    if (valid_d) begin
                        sum_s = 0;
                        for (si = 0; si < HALF_TAPS; si = si + 1)
                            sum_s = sum_s + tap_acc[si];

                        rounded_s = sum_s + (1 << (FRAC_BITS - 1));
                        if (rounded_s[ACC_WIDTH-1:FRAC_BITS+OUTPUT_WIDTH-1] != {(ACC_WIDTH-FRAC_BITS-OUTPUT_WIDTH+1){rounded_s[ACC_WIDTH-1]}})
                            m_axis_tdata <= rounded_s[ACC_WIDTH-1] ?
                                           {1'b1, {(OUTPUT_WIDTH-1){1'b0}}} :
                                           {1'b0, {(OUTPUT_WIDTH-1){1'b1}}};
                        else
                            m_axis_tdata <= rounded_s[FRAC_BITS +: OUTPUT_WIDTH];
                    end
                end
            end

        end
    endgenerate

endmodule
