// Generic pipeline register stage
// Inserts N stages of registered delay with optional enable

module pipeline_reg #(
    parameter DATA_WIDTH = 24,
    parameter STAGES     = 1    // Number of pipeline stages (0 = passthrough)
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    en,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output wire [DATA_WIDTH-1:0]  data_out
);

    generate
        if (STAGES == 0) begin : gen_passthrough
            assign data_out = data_in;
        end else begin : gen_pipeline
            reg [DATA_WIDTH-1:0] stage [0:STAGES-1];

            integer i;
            always @(posedge clk) begin
                if (rst) begin
                    for (i = 0; i < STAGES; i = i + 1)
                        stage[i] <= {DATA_WIDTH{1'b0}};
                end else if (en) begin
                    stage[0] <= data_in;
                    for (i = 1; i < STAGES; i = i + 1)
                        stage[i] <= stage[i-1];
                end
            end

            assign data_out = stage[STAGES-1];
        end
    endgenerate

endmodule
