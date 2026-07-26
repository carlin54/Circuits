module csr (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] csr_addr,
    input  wire [63:0] wdata,
    input  wire [1:0]  csr_op,
    input  wire        csr_write,
    input  wire [4:0]  fflags_in,
    input  wire        fflags_write,
    output reg  [63:0] rdata,
    output wire [2:0]  frm_out,
    output wire [63:0] mepc_out
);

// CSR op encodings
localparam CSR_RW = 2'b00;
localparam CSR_RS = 2'b01;
localparam CSR_RC = 2'b10;

// CSR addresses
localparam ADDR_FFLAGS  = 12'h001;
localparam ADDR_FRM     = 12'h002;
localparam ADDR_FCSR    = 12'h003;
localparam ADDR_MSTATUS = 12'h300;
localparam ADDR_MISA    = 12'h301;
localparam ADDR_MEDELEG = 12'h302;
localparam ADDR_MIDELEG = 12'h303;
localparam ADDR_MIE     = 12'h304;
localparam ADDR_MTVEC   = 12'h305;
localparam ADDR_MSCRATCH = 12'h340;
localparam ADDR_MEPC    = 12'h341;
localparam ADDR_MCAUSE  = 12'h342;
localparam ADDR_MTVAL   = 12'h343;
localparam ADDR_MIP     = 12'h344;
localparam ADDR_MHARTID = 12'hF14;
localparam ADDR_SATP    = 12'h180;
localparam ADDR_STVEC   = 12'h105;

// Internal registers
reg [4:0] fflags_reg;
reg [2:0] frm_reg;
reg [63:0] mepc_reg;
reg [63:0] mtvec_reg;
reg [63:0] mstatus_reg;

assign frm_out = frm_reg;
assign mepc_out = mepc_reg;

// Compute new value based on CSR operation
function [63:0] apply_op;
    input [63:0] old_val;
    input [63:0] wr_data;
    input [1:0]  op;
    begin
        case (op)
            CSR_RW: apply_op = wr_data;
            CSR_RS: apply_op = old_val | wr_data;
            CSR_RC: apply_op = old_val & ~wr_data;
            default: apply_op = old_val;
        endcase
    end
endfunction

// Read logic (combinational)
always @(*) begin
    case (csr_addr)
        ADDR_FFLAGS:  rdata = {59'b0, fflags_reg};
        ADDR_FRM:     rdata = {61'b0, frm_reg};
        ADDR_FCSR:    rdata = {56'b0, frm_reg, fflags_reg};
        ADDR_MEPC:    rdata = mepc_reg;
        ADDR_MTVEC:   rdata = mtvec_reg;
        ADDR_MSTATUS: rdata = mstatus_reg;
        ADDR_MHARTID: rdata = 64'b0;
        ADDR_MCAUSE:  rdata = 64'b0;
        ADDR_MTVAL:   rdata = 64'b0;
        ADDR_MIE:     rdata = 64'b0;
        ADDR_MIP:     rdata = 64'b0;
        ADDR_MISA:    rdata = 64'h800000000014112D; // RV64IMAFD
        default:      rdata = 64'b0;
    endcase
end

// Write logic (synchronous)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fflags_reg  <= 5'b0;
        frm_reg     <= 3'b0;
        mepc_reg    <= 64'b0;
        mtvec_reg   <= 64'b0;
        mstatus_reg <= 64'b0;
    end else begin
        // FPU flag accumulation (sticky OR)
        if (fflags_write)
            fflags_reg <= fflags_reg | fflags_in;

        // CSR write
        if (csr_write) begin
            case (csr_addr)
                ADDR_FFLAGS: fflags_reg <= apply_op({59'b0, fflags_reg}, wdata, csr_op);
                ADDR_FRM:    frm_reg <= apply_op({61'b0, frm_reg}, wdata, csr_op);
                ADDR_FCSR: begin
                    frm_reg    <= apply_op({56'b0, frm_reg, fflags_reg}, wdata, csr_op) >> 5;
                    fflags_reg <= apply_op({56'b0, frm_reg, fflags_reg}, wdata, csr_op);
                end
                ADDR_MEPC:    mepc_reg <= apply_op(mepc_reg, wdata, csr_op);
                ADDR_MTVEC:   mtvec_reg <= apply_op(mtvec_reg, wdata, csr_op);
                ADDR_MSTATUS: mstatus_reg <= apply_op(mstatus_reg, wdata, csr_op);
                default: ; // Unimplemented: ignore write
            endcase
        end
    end
end

endmodule
