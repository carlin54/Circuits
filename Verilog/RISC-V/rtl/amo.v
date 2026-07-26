module amo (
    input  wire [63:0] rs2_data,
    input  wire [63:0] mem_data,
    input  wire [3:0]  amo_op,
    input  wire        is_word,
    output reg  [63:0] result
);

localparam AMOSWAP = 4'b0000;
localparam AMOADD  = 4'b0001;
localparam AMOAND  = 4'b0010;
localparam AMOOR   = 4'b0011;
localparam AMOXOR  = 4'b0100;
localparam AMOMAX  = 4'b0101;
localparam AMOMIN  = 4'b0110;
localparam AMOMAXU = 4'b0111;
localparam AMOMINU = 4'b1000;

wire [31:0] mem_w = mem_data[31:0];
wire [31:0] rs2_w = rs2_data[31:0];

reg [63:0] raw;

always @(*) begin
    if (is_word) begin
        case (amo_op)
            AMOSWAP: raw = {32'b0, rs2_w};
            AMOADD:  raw = {32'b0, mem_w + rs2_w};
            AMOAND:  raw = {32'b0, mem_w & rs2_w};
            AMOOR:   raw = {32'b0, mem_w | rs2_w};
            AMOXOR:  raw = {32'b0, mem_w ^ rs2_w};
            AMOMAX:  raw = {32'b0, ($signed(mem_w) > $signed(rs2_w)) ? mem_w : rs2_w};
            AMOMIN:  raw = {32'b0, ($signed(mem_w) < $signed(rs2_w)) ? mem_w : rs2_w};
            AMOMAXU: raw = {32'b0, (mem_w > rs2_w) ? mem_w : rs2_w};
            AMOMINU: raw = {32'b0, (mem_w < rs2_w) ? mem_w : rs2_w};
            default: raw = 64'b0;
        endcase
        result = {{32{raw[31]}}, raw[31:0]};
    end else begin
        case (amo_op)
            AMOSWAP: result = rs2_data;
            AMOADD:  result = mem_data + rs2_data;
            AMOAND:  result = mem_data & rs2_data;
            AMOOR:   result = mem_data | rs2_data;
            AMOXOR:  result = mem_data ^ rs2_data;
            AMOMAX:  result = ($signed(mem_data) > $signed(rs2_data)) ? mem_data : rs2_data;
            AMOMIN:  result = ($signed(mem_data) < $signed(rs2_data)) ? mem_data : rs2_data;
            AMOMAXU: result = (mem_data > rs2_data) ? mem_data : rs2_data;
            AMOMINU: result = (mem_data < rs2_data) ? mem_data : rs2_data;
            default: result = 64'b0;
        endcase
    end
end

endmodule
