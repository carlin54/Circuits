// Sample Rate Interpolator
// Inserts zeros between samples then filters (CIC or FIR)
// Output rate = input_rate * FACTOR

module interpolator #(
    parameter DATA_WIDTH     = 24,
    parameter FACTOR         = 4,
    parameter FILTER_TYPE    = "CIC",  // "CIC", "FIR"
    parameter CIC_ORDER      = 4,
    parameter FIR_TAPS       = 31,
    parameter FIR_COEFF_FILE = ""
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input (low rate)
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output (high rate = input_rate * FACTOR)
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast
);

    // =========================================================================
    // CIC INTERPOLATOR
    // =========================================================================
    generate
        if (FILTER_TYPE == "CIC") begin : gen_cic

            localparam BIT_GROWTH = CIC_ORDER * $clog2(FACTOR);
            localparam ACC_WIDTH = DATA_WIDTH + BIT_GROWTH;

            // Comb stages (run at input rate)
            reg signed [ACC_WIDTH-1:0] comb [0:CIC_ORDER-1];
            reg signed [ACC_WIDTH-1:0] comb_delay [0:CIC_ORDER-1];

            // Integrator stages (run at output rate)
            reg signed [ACC_WIDTH-1:0] integrator [0:CIC_ORDER-1];

            // Rate expansion counter
            reg [$clog2(FACTOR)-1:0] interp_count;
            reg signed [ACC_WIDTH-1:0] comb_output;
            reg active;
            reg last_saved;

            assign s_axis_tready = !active && (m_axis_tready || !m_axis_tvalid);

            integer ci;
            always @(posedge clk) begin
                if (rst) begin
                    for (ci = 0; ci < CIC_ORDER; ci = ci + 1) begin
                        comb[ci] <= 0;
                        comb_delay[ci] <= 0;
                        integrator[ci] <= 0;
                    end
                    interp_count <= 0;
                    comb_output <= 0;
                    active <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tlast <= 0;
                    last_saved <= 0;
                end else begin
                    if (!active) begin
                        if (m_axis_tvalid && m_axis_tready)
                            m_axis_tvalid <= 0;

                        if (s_axis_tvalid && s_axis_tready) begin
                            // Comb filter (at input rate)
                            reg signed [ACC_WIDTH-1:0] comb_in;
                            comb_in = {{(ACC_WIDTH-DATA_WIDTH){s_axis_tdata[DATA_WIDTH-1]}}, s_axis_tdata};

                            comb[0] <= comb_in - comb_delay[0];
                            comb_delay[0] <= comb_in;
                            for (ci = 1; ci < CIC_ORDER; ci = ci + 1) begin
                                comb[ci] <= comb[ci-1] - comb_delay[ci];
                                comb_delay[ci] <= comb[ci-1];
                            end

                            comb_output <= comb[CIC_ORDER-1];
                            active <= 1;
                            interp_count <= 0;
                            last_saved <= s_axis_tlast;
                        end
                    end else begin
                        if (m_axis_tready || !m_axis_tvalid) begin
                            // Integrator chain (at output rate)
                            // First sample: use comb output; subsequent: insert zeros
                            reg signed [ACC_WIDTH-1:0] interp_in;
                            interp_in = (interp_count == 0) ? comb_output : 0;

                            integrator[0] <= integrator[0] + interp_in;
                            for (ci = 1; ci < CIC_ORDER; ci = ci + 1)
                                integrator[ci] <= integrator[ci] + integrator[ci-1];

                            // Output with gain compensation
                            m_axis_tdata <= integrator[CIC_ORDER-1][ACC_WIDTH-1:BIT_GROWTH];
                            m_axis_tvalid <= 1;
                            m_axis_tlast <= (interp_count == FACTOR - 1) && last_saved;

                            if (interp_count == FACTOR - 1)
                                active <= 0;
                            else
                                interp_count <= interp_count + 1;
                        end
                    end
                end
            end

        end
    endgenerate

    // =========================================================================
    // FIR INTERPOLATOR (zero-stuffing + filter)
    // =========================================================================
    generate
        if (FILTER_TYPE == "FIR") begin : gen_fir

            reg signed [DATA_WIDTH-1:0] delay_line [0:FIR_TAPS-1];
            reg signed [15:0] coeffs [0:FIR_TAPS-1];

            localparam ACC_WIDTH = DATA_WIDTH + 16 + $clog2(FIR_TAPS);

            reg [$clog2(FACTOR)-1:0] phase;
            reg active;
            reg last_saved;

            assign s_axis_tready = !active && (m_axis_tready || !m_axis_tvalid);

            initial begin
                if (FIR_COEFF_FILE != "")
                    $readmemh(FIR_COEFF_FILE, coeffs);
            end

            integer fi;
            always @(posedge clk) begin
                if (rst) begin
                    for (fi = 0; fi < FIR_TAPS; fi = fi + 1)
                        delay_line[fi] <= 0;
                    phase <= 0;
                    active <= 0;
                    m_axis_tdata <= 0;
                    m_axis_tvalid <= 0;
                    m_axis_tlast <= 0;
                    last_saved <= 0;
                end else begin
                    if (!active) begin
                        if (m_axis_tvalid && m_axis_tready)
                            m_axis_tvalid <= 0;

                        if (s_axis_tvalid && s_axis_tready) begin
                            // Shift new sample into delay line
                            for (fi = FIR_TAPS-1; fi > 0; fi = fi - 1)
                                delay_line[fi] <= delay_line[fi-1];
                            delay_line[0] <= s_axis_tdata;
                            active <= 1;
                            phase <= 0;
                            last_saved <= s_axis_tlast;
                        end
                    end else begin
                        if (m_axis_tready || !m_axis_tvalid) begin
                            // Polyphase: compute output for each phase
                            reg signed [ACC_WIDTH-1:0] acc;
                            acc = 0;
                            for (fi = 0; fi < FIR_TAPS; fi = fi + 1) begin
                                // Polyphase coefficient index
                                if ((fi * FACTOR + phase) < FIR_TAPS)
                                    acc = acc + delay_line[fi] * coeffs[fi * FACTOR + phase];
                            end

                            m_axis_tdata <= acc >>> 15;
                            m_axis_tvalid <= 1;
                            m_axis_tlast <= (phase == FACTOR - 1) && last_saved;

                            if (phase == FACTOR - 1)
                                active <= 0;
                            else
                                phase <= phase + 1;
                        end
                    end
                end
            end

        end
    endgenerate

endmodule
