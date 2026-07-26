module mem #(
    parameter SIZE      = 65536,
    parameter BASE_ADDR = 64'h80000000,
    parameter UART_ADDR = 64'h10000000,
    parameter HEX_FILE  = ""
)(
    input  wire        clk,
    input  wire [63:0] addr,
    input  wire [63:0] wdata,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  mem_size,
    input  wire        mem_unsigned,
    input  wire        mem_fetch,
    output reg  [31:0] instr,
    output reg  [63:0] rdata,
    output wire        out_of_bounds,
    output reg  [7:0]  uart_tx_data,
    output reg         uart_tx_valid
);

reg [7:0] mem [0:SIZE-1];

wire [63:0] offset = addr - BASE_ADDR;
wire        is_uart = (addr == UART_ADDR);
assign out_of_bounds = !is_uart && ((addr < BASE_ADDR) || (offset >= SIZE));
wire [15:0] off = offset[15:0];

// Instruction fetch (always 32-bit, little-endian)
always @(*) begin
    if (mem_fetch && !out_of_bounds) begin
        instr[7:0]   = mem[off];
        instr[15:8]  = mem[off + 1];
        instr[23:16] = mem[off + 2];
        instr[31:24] = mem[off + 3];
    end else begin
        instr = 32'b0;
    end
end

// Data read (combinational)
always @(*) begin
    rdata = 64'b0;
    if (mem_read && !out_of_bounds) begin
        case (mem_size)
            3'b000: begin
                rdata[7:0] = mem[off];
                if (!mem_unsigned)
                    rdata[63:8] = {56{rdata[7]}};
            end
            3'b001: begin
                rdata[7:0]  = mem[off];
                rdata[15:8] = mem[off + 1];
                if (!mem_unsigned)
                    rdata[63:16] = {48{rdata[15]}};
            end
            3'b010: begin
                rdata[7:0]   = mem[off];
                rdata[15:8]  = mem[off + 1];
                rdata[23:16] = mem[off + 2];
                rdata[31:24] = mem[off + 3];
                if (!mem_unsigned)
                    rdata[63:32] = {32{rdata[31]}};
            end
            3'b011: begin
                rdata[7:0]   = mem[off];
                rdata[15:8]  = mem[off + 1];
                rdata[23:16] = mem[off + 2];
                rdata[31:24] = mem[off + 3];
                rdata[39:32] = mem[off + 4];
                rdata[47:40] = mem[off + 5];
                rdata[55:48] = mem[off + 6];
                rdata[63:56] = mem[off + 7];
            end
            default: rdata = 64'b0;
        endcase
    end
end

// Synchronous write (little-endian)
always @(posedge clk) begin
    uart_tx_valid <= 0;
    if (mem_write) begin
        if (is_uart) begin
            uart_tx_data <= wdata[7:0];
            uart_tx_valid <= 1;
        end else if (!out_of_bounds) begin
            case (mem_size)
                3'b000: mem[off] <= wdata[7:0];
                3'b001: begin
                    mem[off]     <= wdata[7:0];
                    mem[off + 1] <= wdata[15:8];
                end
                3'b010: begin
                    mem[off]     <= wdata[7:0];
                    mem[off + 1] <= wdata[15:8];
                    mem[off + 2] <= wdata[23:16];
                    mem[off + 3] <= wdata[31:24];
                end
                3'b011: begin
                    mem[off]     <= wdata[7:0];
                    mem[off + 1] <= wdata[15:8];
                    mem[off + 2] <= wdata[23:16];
                    mem[off + 3] <= wdata[31:24];
                    mem[off + 4] <= wdata[39:32];
                    mem[off + 5] <= wdata[47:40];
                    mem[off + 6] <= wdata[55:48];
                    mem[off + 7] <= wdata[63:56];
                end
                default: ;
            endcase
        end
    end
end

// Load hex file at initialization
initial begin
    if (HEX_FILE != "")
        $readmemh(HEX_FILE, mem);
end

endmodule
