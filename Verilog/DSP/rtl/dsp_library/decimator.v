// Sample Rate Decimator
// Supports CIC (no multipliers) and FIR (anti-alias filter) modes
// CIC: Cascaded Integrator-Comb filter

module decimator #(
    parameter DATA_WIDTH     = 24,
    parameter FACTOR         = 4,
    parameter FILTER_TYPE    = "CIC",  // "CIC", "FIR"
    parameter CIC_ORDER      = 4,
    parameter CIC_DIFF_DELAY = 1,
    parameter FIR_TAPS       = 31,
    parameter FIR_COEFF_FILE = ""
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input (high rate)
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output (low rate = input_rate / FACTOR)
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast
);

    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // =========================================================================
    // CIC DECIMATOR
    // =========================================================================
    generate
        if (FILTER_TYPE == "CIC") begin : gen_cic

            // Bit growth for CIC: CIC_ORDER * log2(FACTOR * CIC_DIFF_DELAY)
            localparam BIT_GROWTH = CIC_ORDER * $clog2(FACTOR * CIC_DIFF_DELAY);
            localparam ACC_WIDTH = DATA_WIDTH + BIT_GROWTH;

            // Integrator stages (run at input rate)
            reg signed [ACC_WIDTH-1:0] integrator [0:CIC_ORDER-1];

            // Comb stages (run at output rate)
            reg signed [ACC_WIDTH-1:0] comb [0:CIC_ORDER-1];
            reg signed [ACC_WIDTH-1:0] comb_delay [0:CIC_ORDER-1];

            // Decimation counter
            reg [$clog2(FACTOR)-1:0] dec_count;
            wire decimate_now = (dec_count == FACTOR - 1);

            integer ci;
            always @(posedge clk) begin
                if (rst) begin
                    for (ci = 0; ci < CIC_ORDER; ci = ci + 1) begin
                        integrator[ci] <= 0;
                        comb[ci] <= 0;
                        comb_delay[ci] <= 0;
                    end
                    dec_count <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tlast <= 0;
                end else if (s_axis_tready) begin
                    m_axis_tvalid <= 0;

                    if (s_axis_tvalid) begin
                        // Integrator chain (runs every input sample)
                        integrator[0] <= integrator[0] + {{(ACC_WIDTH-DATA_WIDTH){s_axis_tdata[DATA_WIDTH-1]}}, s_axis_tdata};
                        for (ci = 1; ci < CIC_ORDER; ci = ci + 1)
                            integrator[ci] <= integrator[ci] + integrator[ci-1];

                        // Decimation counter
                        if (dec_count == FACTOR - 1) begin
                            dec_count <= 0;

                            // Comb chain (runs at decimated rate)
                            comb[0] <= integrator[CIC_ORDER-1] - comb_delay[0];
                            comb_delay[0] <= integrator[CIC_ORDER-1];
                            for (ci = 1; ci < CIC_ORDER; ci = ci + 1) begin
                                comb[ci] <= comb[ci-1] - comb_delay[ci];
                                comb_delay[ci] <= comb[ci-1];
                            end

                            // Output: truncate back to DATA_WIDTH
                            m_axis_tdata <= comb[CIC_ORDER-1][ACC_WIDTH-1:BIT_GROWTH];
                            m_axis_tvalid <= 1;
                            m_axis_tlast <= s_axis_tlast;
                        end else begin
                            dec_count <= dec_count + 1;
                        end
                    end
                end
            end

        end
    endgenerate

    // =========================================================================
    // FIR DECIMATOR (polyphase)
    // =========================================================================
    generate
        if (FILTER_TYPE == "FIR") begin : gen_fir

            // Simple approach: FIR filter at input rate, then keep every FACTOR-th sample
            reg signed [DATA_WIDTH-1:0] delay_line [0:FIR_TAPS-1];
            reg signed [15:0] coeffs [0:FIR_TAPS-1];  // 16-bit coefficients

            localparam ACC_WIDTH = DATA_WIDTH + 16 + $clog2(FIR_TAPS);
            reg signed [ACC_WIDTH-1:0] accumulator;
            reg [$clog2(FACTOR)-1:0] dec_count;
            reg [$clog2(FIR_TAPS):0] tap_count;
            reg processing;
            reg last_saved;

            initial begin
                if (FIR_COEFF_FILE != "")
                    $readmemh(FIR_COEFF_FILE, coeffs);
            end

            integer fi;
            always @(posedge clk) begin
                if (rst) begin
                    for (fi = 0; fi < FIR_TAPS; fi = fi + 1)
                        delay_line[fi] <= 0;
                    dec_count <= 0;
                    accumulator <= 0;
                    tap_count <= 0;
                    processing <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tlast <= 0;
                    last_saved <= 0;
                end else begin
                    if (!processing) begin
                        if (s_axis_tvalid && s_axis_tready) begin
                            // Shift delay line
                            for (fi = FIR_TAPS-1; fi > 0; fi = fi - 1)
                                delay_line[fi] <= delay_line[fi-1];
                            delay_line[0] <= s_axis_tdata;

                            // Only compute output on decimation point
                            if (dec_count == FACTOR - 1) begin
                                dec_count <= 0;
                                accumulator <= 0;
                                tap_count <= 0;
                                processing <= 1;
                                last_saved <= s_axis_tlast;
                            end else begin
                                dec_count <= dec_count + 1;
                            end
                        end
                        if (m_axis_tvalid && m_axis_tready)
                            m_axis_tvalid <= 0;
                    end else begin
                        accumulator <= accumulator + delay_line[tap_count] * coeffs[tap_count];
                        tap_count <= tap_count + 1;
                        if (tap_count == FIR_TAPS - 1) begin
                            processing <= 0;
                            m_axis_tdata <= (accumulator + delay_line[tap_count] * coeffs[tap_count]) >>> 15;
                            m_axis_tvalid <= 1;
                            m_axis_tlast <= last_saved;
                        end
                    end
                end
            end

            assign s_axis_tready = !processing && (m_axis_tready || !m_axis_tvalid);

        end
    endgenerate

endmodule
