module top #(
    parameter MEM_SIZE  = 16384,
    parameter BASE_ADDR = 64'h80000000,
    parameter HEX_FILE  = ""
)(
    input  wire        clk,
    input  wire        rst_n,
    output wire        halt,
    output wire [7:0]  uart_tx_data,
    output wire        uart_tx_valid
);

// Internal wires
wire [63:0] pc_out;
wire [63:0] next_pc;
wire        pc_write;

wire [31:0] instr_out;
wire        ir_write;
wire [31:0] mem_instr;

wire [6:0]  opcode;
wire [4:0]  rd, rs1, rs2, rs3;
wire [2:0]  funct3;
wire [6:0]  funct7;
wire [1:0]  fmt;
wire [4:0]  funct5;
wire [63:0] imm;
wire [11:0] imm_i;

wire [2:0]  state;
wire        reg_write, fp_reg_write;
wire [3:0]  alu_op;
wire [1:0]  alu_src_a;
wire        alu_src_b;
wire        is_word_op;
wire        mem_read, mem_write_ctrl;
wire [2:0]  mem_size;
wire        mem_unsigned;
wire        mem_fetch;
wire [2:0]  wb_src;
wire [1:0]  pc_src;
wire        muldiv_start;
wire [3:0]  muldiv_op;
wire [4:0]  fpu_op;
wire        fpu_start;
wire [2:0]  fpu_rm;
wire        fpu_single;
wire [3:0]  amo_op;
wire        amo_en;
wire        amo_word;
wire        csr_write;
wire [1:0]  csr_op;
wire        fflags_write;

wire [63:0] rs1_data, rs2_data;
wire [63:0] fp_rs1_data, fp_rs2_data, fp_rs3_data;

wire [63:0] alu_result;
wire [63:0] muldiv_result;
wire        muldiv_done, muldiv_busy;
wire [63:0] fpu_result;
wire [4:0]  fpu_fflags;
wire        fpu_done, fpu_busy;
wire        branch_taken;
wire [63:0] amo_result;
wire [63:0] csr_rdata;
wire [2:0]  frm_out;
wire [63:0] mepc_out;

wire [63:0] mem_rdata;
wire [31:0] mem_instr_out;
wire        mem_oob;

// Internal latches
reg [63:0] A, B, C, IMM_reg, ALU_OUT, MEM_DATA, BRANCH_TARGET;

// LR/SC reservation registers
reg        reservation_valid;
reg [63:0] reservation_addr;

// Memory address MUX
wire [63:0] mem_addr = (state == 3'b000) ? pc_out : ALU_OUT;

// Memory write data MUX
wire [63:0] mem_wdata = amo_en ? amo_result : B;

// SC conditional write: suppress mem_write if SC fails
wire mem_write_actual = is_sc_op ? (mem_write_ctrl && sc_success) : mem_write_ctrl;

// ALU input MUXes
wire [63:0] alu_a = (alu_src_a == 2'b00) ? A :
                    (alu_src_a == 2'b01) ? pc_out :
                    64'b0;
wire [63:0] alu_b = alu_src_b ? IMM_reg : B;

// Writeback data MUX
wire [63:0] wb_data = (wb_src == 3'b000) ? ALU_OUT :
                      (wb_src == 3'b001) ? MEM_DATA :
                      (wb_src == 3'b010) ? fpu_result :
                      (wb_src == 3'b011) ? (pc_out + 64'd4) :
                      (wb_src == 3'b100) ? csr_rdata :
                      (wb_src == 3'b101) ? muldiv_result :
                      64'b0;

// Next PC MUX
assign next_pc = (pc_src == 2'b00) ? (pc_out + 64'd4) :
                 (pc_src == 2'b01) ? BRANCH_TARGET :
                 (pc_src == 2'b10) ? {ALU_OUT[63:1], 1'b0} :
                 mepc_out; // 2'b11 = mret

// Module instantiations
pc #(.RESET_ADDR(BASE_ADDR)) pc_inst (
    .clk(clk), .rst_n(rst_n),
    .pc_write(pc_write), .next_pc(next_pc),
    .pc_out(pc_out)
);

ir ir_inst (
    .clk(clk), .rst_n(rst_n),
    .ir_write(ir_write), .instr_in(mem_instr_out),
    .instr_out(instr_out)
);

mem #(.SIZE(MEM_SIZE), .BASE_ADDR(BASE_ADDR), .HEX_FILE(HEX_FILE)) memory (
    .clk(clk),
    .addr(mem_addr), .wdata(mem_wdata),
    .mem_read(mem_read), .mem_write(mem_write_actual),
    .mem_size(mem_size), .mem_unsigned(mem_unsigned),
    .mem_fetch(mem_fetch),
    .instr(mem_instr_out), .rdata(mem_rdata),
    .out_of_bounds(mem_oob),
    .uart_tx_data(uart_tx_data), .uart_tx_valid(uart_tx_valid)
);

decoder decode (
    .instr(instr_out),
    .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2), .rs3(rs3),
    .funct3(funct3), .funct7(funct7), .fmt(fmt), .funct5(funct5),
    .imm(imm), .imm_i(imm_i)
);

control ctrl (
    .clk(clk), .rst_n(rst_n),
    .opcode(opcode), .funct3(funct3), .funct7(funct7),
    .funct5(funct5), .fmt(fmt), .rs2_addr(rs2), .imm_i(imm_i),
    .branch_taken(branch_taken),
    .fpu_done(fpu_done), .muldiv_done(muldiv_done),
    .frm(frm_out),
    .state(state), .pc_write(pc_write), .ir_write(ir_write),
    .reg_write(reg_write), .fp_reg_write(fp_reg_write),
    .alu_op(alu_op), .alu_src_a(alu_src_a), .alu_src_b(alu_src_b),
    .is_word_op(is_word_op),
    .mem_read(mem_read), .mem_write(mem_write_ctrl),
    .mem_size(mem_size), .mem_unsigned(mem_unsigned), .mem_fetch(mem_fetch),
    .wb_src(wb_src), .pc_src(pc_src),
    .muldiv_start(muldiv_start), .muldiv_op(muldiv_op),
    .fpu_op(fpu_op), .fpu_start(fpu_start), .fpu_rm(fpu_rm), .fpu_single(fpu_single),
    .amo_op(amo_op), .amo_en(amo_en), .amo_word(amo_word),
    .csr_write(csr_write), .csr_op(csr_op), .fflags_write(fflags_write),
    .halt(halt)
);

regfile regs (
    .clk(clk),
    .rs1_addr(rs1), .rs2_addr(rs2),
    .rd_addr(rd), .rd_data(wb_data_final), .reg_write(reg_write),
    .rs1_data(rs1_data), .rs2_data(rs2_data)
);

fp_regfile fp_regs (
    .clk(clk),
    .rs1_addr(rs1), .rs2_addr(rs2), .rs3_addr(rs3),
    .rd_addr(rd), .rd_data(wb_data_final), .fp_reg_write(fp_reg_write),
    .rs1_data(fp_rs1_data), .rs2_data(fp_rs2_data), .rs3_data(fp_rs3_data)
);

alu alu_inst (
    .a(alu_a), .b(alu_b),
    .alu_op(alu_op), .is_word_op(is_word_op),
    .result(alu_result)
);

muldiv muldiv_inst (
    .clk(clk), .rst_n(rst_n),
    .start(muldiv_start), .a(A), .b(B),
    .op(muldiv_op), .is_word_op(is_word_op),
    .result(muldiv_result), .done(muldiv_done), .busy(muldiv_busy)
);

fpu fpu_inst (
    .clk(clk), .rst_n(rst_n),
    .start(fpu_start), .a(A), .b(B), .c(C),
    .op(fpu_op), .single(fpu_single), .rm(fpu_rm),
    .result(fpu_result), .fflags(fpu_fflags),
    .done(fpu_done), .busy(fpu_busy)
);

branch branch_inst (
    .a(A), .b(B),
    .branch_type(funct3),
    .taken(branch_taken)
);

amo amo_inst (
    .rs2_data(B), .mem_data(MEM_DATA),
    .amo_op(amo_op), .is_word(amo_word),
    .result(amo_result)
);

// CSR wdata: for CSRRWI/CSRRSI/CSRRCI (funct3[2]=1), use zero-extended uimm (rs1 field)
wire [63:0] csr_wdata = funct3[2] ? {59'b0, rs1} : A;

csr csr_inst (
    .clk(clk), .rst_n(rst_n),
    .csr_addr(imm_i), .wdata(csr_wdata),
    .csr_op(csr_op), .csr_write(csr_write),
    .fflags_in(fpu_fflags), .fflags_write(fflags_write),
    .rdata(csr_rdata), .frm_out(frm_out), .mepc_out(mepc_out)
);

// FP source detection for DECODE latch muxing
wire fp_reads_fp_rs1 = (opcode == 7'b1010011 && !(funct5[4:3] == 2'b11 && funct5[1])) ||
                       (opcode == 7'b1000011) || (opcode == 7'b1000111) ||
                       (opcode == 7'b1001011) || (opcode == 7'b1001111);
wire fp_reads_fp_rs2 = fp_reads_fp_rs1 || (opcode == 7'b0100111); // STORE-FP uses fp rs2

// Writeback data with NaN-boxing for FLW (funct3==010 means word-size FP load)
wire [63:0] wb_data_final;
assign wb_data_final = (wb_src == 3'b001 && fp_reg_write && funct3 == 3'b010) ?
                       {32'hFFFFFFFF, MEM_DATA[31:0]} : wb_data;

// LR/SC detection wires
wire is_lr_op = (opcode == 7'b0101111) && (funct7[6:2] == 5'b00010);
wire is_sc_op = (opcode == 7'b0101111) && (funct7[6:2] == 5'b00011);
wire sc_success = reservation_valid && (reservation_addr == ALU_OUT);

// Latch updates (DECODE and EXECUTE stages)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        A <= 64'b0;
        B <= 64'b0;
        C <= 64'b0;
        IMM_reg <= 64'b0;
        ALU_OUT <= 64'b0;
        MEM_DATA <= 64'b0;
        BRANCH_TARGET <= 64'b0;
        reservation_valid <= 0;
        reservation_addr  <= 64'b0;
    end else begin
        if (state == 3'b001) begin // DECODE
            A <= fp_reads_fp_rs1 ? fp_rs1_data : rs1_data;
            B <= fp_reads_fp_rs2 ? fp_rs2_data : rs2_data;
            C <= fp_rs3_data;
            IMM_reg <= imm;
            BRANCH_TARGET <= pc_out + imm;
        end
        if (state == 3'b010) begin // EXECUTE
            ALU_OUT <= alu_result;
        end
        if (state == 3'b011) begin // MEMORY
            if (is_lr_op) begin
                MEM_DATA <= mem_rdata;
                reservation_valid <= 1;
                reservation_addr  <= ALU_OUT;
            end else if (is_sc_op) begin
                MEM_DATA <= sc_success ? 64'd0 : 64'd1;
                reservation_valid <= 0;
            end else if (mem_read) begin
                MEM_DATA <= mem_rdata;
            end
            // Any store invalidates reservation
            if (mem_write_ctrl && !is_sc_op)
                reservation_valid <= 0;
        end
    end
end

endmodule
