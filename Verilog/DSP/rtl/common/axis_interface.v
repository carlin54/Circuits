// AXI-Stream pipeline register / handshaking wrapper
// Inserts a pipeline stage between source and sink for timing improvement
// Supports optional backpressure and output registration

module axis_interface #(
    parameter DATA_WIDTH     = 24,
    parameter REGISTER_OUTPUT = 1,  // 1 = insert pipeline register, 0 = passthrough
    parameter BACKPRESSURE   = 1    // 1 = support ready-based flow control
)(
    input  wire                         clk,
    input  wire                         rst,

    // Slave (input) interface
    input  wire signed [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,

    // Master (output) interface
    output wire signed [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast
);

    generate
        if (REGISTER_OUTPUT == 0) begin : gen_passthrough
            assign m_axis_tdata  = s_axis_tdata;
            assign m_axis_tvalid = s_axis_tvalid;
            assign m_axis_tlast  = s_axis_tlast;
            assign s_axis_tready = BACKPRESSURE ? m_axis_tready : 1'b1;
        end else begin : gen_registered
            // Skid buffer: allows full throughput even with registered output
            reg signed [DATA_WIDTH-1:0] data_reg;
            reg                         valid_reg;
            reg                         last_reg;

            reg signed [DATA_WIDTH-1:0] skid_data;
            reg                         skid_valid;
            reg                         skid_last;

            wire output_ready;
            assign output_ready = BACKPRESSURE ? m_axis_tready : 1'b1;

            wire can_accept;
            assign can_accept = ~valid_reg | output_ready;

            assign s_axis_tready = BACKPRESSURE ? (~skid_valid) : 1'b1;
            assign m_axis_tdata  = data_reg;
            assign m_axis_tvalid = valid_reg;
            assign m_axis_tlast  = last_reg;

            always @(posedge clk) begin
                if (rst) begin
                    valid_reg  <= 1'b0;
                    skid_valid <= 1'b0;
                    data_reg   <= {DATA_WIDTH{1'b0}};
                    last_reg   <= 1'b0;
                    skid_data  <= {DATA_WIDTH{1'b0}};
                    skid_last  <= 1'b0;
                end else begin
                    // Output register consumed
                    if (output_ready) begin
                        if (skid_valid) begin
                            data_reg   <= skid_data;
                            valid_reg  <= 1'b1;
                            last_reg   <= skid_last;
                            skid_valid <= 1'b0;
                        end else if (s_axis_tvalid && s_axis_tready) begin
                            data_reg  <= s_axis_tdata;
                            valid_reg <= 1'b1;
                            last_reg  <= s_axis_tlast;
                        end else begin
                            valid_reg <= 1'b0;
                        end
                    end else begin
                        // Output stalled — capture input in skid buffer
                        if (s_axis_tvalid && s_axis_tready) begin
                            skid_data  <= s_axis_tdata;
                            skid_valid <= 1'b1;
                            skid_last  <= s_axis_tlast;
                        end
                    end
                end
            end
        end
    endgenerate

endmodule
