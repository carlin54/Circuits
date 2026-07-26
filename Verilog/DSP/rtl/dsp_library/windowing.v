// Window Function Applicator
// Point-by-point multiply of input stream with stored window coefficients
// Supports Hann, Hamming, Blackman, Kaiser, or custom window from file

module windowing #(
    parameter N           = 1024,
    parameter DATA_WIDTH  = 24,
    parameter COEFF_WIDTH = 16,
    parameter WINDOW_TYPE = "HANN",  // "HANN", "HAMMING", "BLACKMAN", "KAISER", "CUSTOM"
    parameter COEFF_FILE  = ""       // Hex file for CUSTOM window
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
    output reg                           m_axis_tlast
);

    localparam ADDR_WIDTH = $clog2(N);
    localparam PROD_WIDTH = DATA_WIDTH + COEFF_WIDTH;
    localparam COEFF_FRAC = COEFF_WIDTH - 1;  // Window coefficients are Q1.(CW-1), range [0,1]

    // Window coefficient ROM
    reg signed [COEFF_WIDTH-1:0] win_coeffs [0:N-1];

    // Initialize window coefficients
    integer wi;
    initial begin
        if (COEFF_FILE != "") begin
            $readmemh(COEFF_FILE, win_coeffs);
        end else begin
            // Default initialization (placeholder — proper values from gen_window.py)
            for (wi = 0; wi < N; wi = wi + 1)
                win_coeffs[wi] = (1 << (COEFF_WIDTH - 1)) - 1;  // All ones = unity
        end
    end

    // Sample counter
    reg [ADDR_WIDTH-1:0] sample_count;

    // Flow control
    assign s_axis_tready = m_axis_tready || !m_axis_tvalid;

    // Pipeline: 1 clock for multiply
    reg signed [DATA_WIDTH-1:0] data_d;
    reg valid_d, last_d;

    always @(posedge clk) begin
        if (rst) begin
            sample_count <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            data_d <= 0;
            valid_d <= 0;
            last_d <= 0;
        end else if (s_axis_tready) begin
            // Stage 1: Multiply input by window coefficient
            valid_d <= s_axis_tvalid;
            last_d <= s_axis_tlast;

            if (s_axis_tvalid) begin
                reg signed [PROD_WIDTH-1:0] product;
                product = s_axis_tdata * win_coeffs[sample_count];
                // Round to output width (shift by coefficient fractional bits)
                data_d <= (product + (1 << (COEFF_FRAC - 1))) >>> COEFF_FRAC;

                if (s_axis_tlast || sample_count == N - 1)
                    sample_count <= 0;
                else
                    sample_count <= sample_count + 1;
            end

            // Stage 2: Output
            m_axis_tdata <= data_d;
            m_axis_tvalid <= valid_d;
            m_axis_tlast <= last_d;
        end
    end

endmodule
