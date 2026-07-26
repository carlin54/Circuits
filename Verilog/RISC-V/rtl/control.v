module control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [4:0]  funct5,
    input  wire [1:0]  fmt,
    input  wire [4:0]  rs2_addr,
    input  wire [11:0] imm_i,
    input  wire        branch_taken,
    input  wire        fpu_done,
    input  wire        muldiv_done,
    input  wire [2:0]  frm,

    output reg  [2:0]  state,
    output reg         pc_write,
    output reg         ir_write,
    output reg         reg_write,
    output reg         fp_reg_write,
    output reg  [3:0]  alu_op,
    output reg  [1:0]  alu_src_a,
    output reg         alu_src_b,
    output reg         is_word_op,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [2:0]  mem_size,
    output reg         mem_unsigned,
    output reg         mem_fetch,
    output reg  [2:0]  wb_src,
    output reg  [1:0]  pc_src,
    output reg         muldiv_start,
    output reg  [3:0]  muldiv_op,
    output reg  [4:0]  fpu_op,
    output reg         fpu_start,
    output reg  [2:0]  fpu_rm,
    output reg         fpu_single,
    output reg  [3:0]  amo_op,
    output reg         amo_en,
    output reg         amo_word,
    output reg         csr_write,
    output reg  [1:0]  csr_op,
    output reg         fflags_write,
    output reg         halt
);

// FSM state encodings
localparam FETCH       = 3'b000;
localparam DECODE      = 3'b001;
localparam EXECUTE     = 3'b010;
localparam MEMORY      = 3'b011;
localparam WRITEBACK   = 3'b100;
localparam FP_EXEC     = 3'b101;
localparam MULDIV_EXEC = 3'b110;

// Opcode encodings
localparam OP        = 7'b0110011;
localparam OP_32     = 7'b0111011;
localparam OP_IMM    = 7'b0010011;
localparam OP_IMM_32 = 7'b0011011;
localparam LUI       = 7'b0110111;
localparam AUIPC     = 7'b0010111;
localparam JAL       = 7'b1101111;
localparam JALR      = 7'b1100111;
localparam BRANCH    = 7'b1100011;
localparam LOAD      = 7'b0000011;
localparam STORE     = 7'b0100011;
localparam LOAD_FP   = 7'b0000111;
localparam STORE_FP  = 7'b0100111;
localparam AMO       = 7'b0101111;
localparam MADD      = 7'b1000011;
localparam MSUB      = 7'b1000111;
localparam NMSUB     = 7'b1001011;
localparam NMADD     = 7'b1001111;
localparam OP_FP     = 7'b1010011;
localparam MISC_MEM  = 7'b0001111;
localparam SYSTEM    = 7'b1110011;

// ALU op encodings
localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_AND  = 4'b0010;
localparam ALU_OR   = 4'b0011;
localparam ALU_XOR  = 4'b0100;
localparam ALU_SLL  = 4'b0101;
localparam ALU_SRL  = 4'b0110;
localparam ALU_SRA  = 4'b0111;
localparam ALU_SLT  = 4'b1000;
localparam ALU_SLTU = 4'b1001;
localparam ALU_PASSB = 4'b1010;

// AMO mem_cycle counter
reg [1:0] mem_cycle;

// Detect M-extension (funct7 == 0000001)
wire is_mext = (funct7 == 7'b0000001);

// Detect ECALL/EBREAK
wire is_ecall_ebreak = (opcode == SYSTEM) && (funct3 == 3'b000) && (imm_i == 12'h000 || imm_i == 12'h001);

// Detect MRET (imm_i = 0x302)
wire is_mret = (opcode == SYSTEM) && (funct3 == 3'b000) && (imm_i == 12'h302);

// Detect CSR instructions
wire is_csr = (opcode == SYSTEM) && (funct3 != 3'b000);

// Detect FP multi-cycle ops (FDIV, FSQRT)
wire is_fp_multicycle = (opcode == OP_FP) && (funct5 == 5'b01100 || funct5 == 5'b01011);

// Detect LR/SC
wire is_lr = (opcode == AMO) && (funct7[6:2] == 5'b00010);
wire is_sc = (opcode == AMO) && (funct7[6:2] == 5'b00011);
wire is_amo = (opcode == AMO) && !is_lr && !is_sc;

// Needs MEMORY state
wire needs_memory = (opcode == LOAD) || (opcode == STORE) ||
                    (opcode == LOAD_FP) || (opcode == STORE_FP) ||
                    (opcode == AMO);

// Derive alu_op from funct3/funct7 for R-type and I-type
reg [3:0] derived_alu_op;
always @(*) begin
    case (funct3)
        3'b000: derived_alu_op = (opcode == OP || opcode == OP_32) && funct7[5] ? ALU_SUB : ALU_ADD;
        3'b001: derived_alu_op = ALU_SLL;
        3'b010: derived_alu_op = ALU_SLT;
        3'b011: derived_alu_op = ALU_SLTU;
        3'b100: derived_alu_op = ALU_XOR;
        3'b101: derived_alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
        3'b110: derived_alu_op = ALU_OR;
        3'b111: derived_alu_op = ALU_AND;
    endcase
end

// Derive AMO operation from funct7[6:2]
reg [3:0] derived_amo_op;
always @(*) begin
    case (funct7[6:2])
        5'b00001: derived_amo_op = 4'b0000; // AMOSWAP
        5'b00000: derived_amo_op = 4'b0001; // AMOADD
        5'b01100: derived_amo_op = 4'b0010; // AMOAND
        5'b01000: derived_amo_op = 4'b0011; // AMOOR
        5'b00100: derived_amo_op = 4'b0100; // AMOXOR
        5'b10100: derived_amo_op = 4'b0101; // AMOMAX
        5'b10000: derived_amo_op = 4'b0110; // AMOMIN
        5'b11100: derived_amo_op = 4'b0111; // AMOMAXU
        5'b11000: derived_amo_op = 4'b1000; // AMOMINU
        default:  derived_amo_op = 4'b0000;
    endcase
end

// Resolve FPU rounding mode
wire [2:0] resolved_rm = (funct3 == 3'b111) ? frm : funct3;

// FSM state transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= FETCH;
        mem_cycle <= 2'b0;
    end else begin
        case (state)
            FETCH: state <= DECODE;
            DECODE: state <= EXECUTE;
            EXECUTE: begin
                if (needs_memory)
                    state <= MEMORY;
                else if ((opcode == OP || opcode == OP_32) && is_mext)
                    state <= MULDIV_EXEC;
                else if (is_fp_multicycle)
                    state <= FP_EXEC;
                else
                    state <= WRITEBACK;
            end
            MEMORY: begin
                if (is_amo) begin
                    if (mem_cycle == 2'd2) begin
                        state <= WRITEBACK;
                        mem_cycle <= 2'b0;
                    end else begin
                        mem_cycle <= mem_cycle + 1;
                    end
                end else begin
                    state <= WRITEBACK;
                end
            end
            WRITEBACK: begin
                state <= FETCH;
                mem_cycle <= 2'b0;
            end
            FP_EXEC: begin
                if (fpu_done)
                    state <= WRITEBACK;
            end
            MULDIV_EXEC: begin
                if (muldiv_done)
                    state <= WRITEBACK;
            end
            default: state <= FETCH;
        endcase
    end
end

// Combinational control signal generation
always @(*) begin
    // Defaults
    pc_write     = 0;
    ir_write     = 0;
    reg_write    = 0;
    fp_reg_write = 0;
    alu_op       = ALU_ADD;
    alu_src_a    = 2'b00;
    alu_src_b    = 1'b0;
    is_word_op   = 0;
    mem_read     = 0;
    mem_write    = 0;
    mem_size     = 3'b0;
    mem_unsigned = 0;
    mem_fetch    = 0;
    wb_src       = 3'b000;
    pc_src       = 2'b00;
    muldiv_start = 0;
    muldiv_op    = 4'b0;
    fpu_op       = 5'b0;
    fpu_start    = 0;
    fpu_rm       = 3'b0;
    fpu_single   = 0;
    amo_op       = 4'b0;
    amo_en       = 0;
    amo_word     = 0;
    csr_write    = 0;
    csr_op       = 2'b0;
    fflags_write = 0;
    halt         = 0;

    case (state)
        FETCH: begin
            ir_write  = 1;
            mem_fetch = 1;
            mem_read  = 1;
        end

        DECODE: begin
            // Nothing special — latches loaded by top.v
        end

        EXECUTE: begin
            case (opcode)
                OP: begin
                    if (is_mext) begin
                        muldiv_start = 1;
                        muldiv_op    = {1'b0, funct3};
                        is_word_op   = 0;
                    end else begin
                        alu_op    = derived_alu_op;
                        alu_src_a = 2'b00;
                        alu_src_b = 1'b0;
                        is_word_op = 0;
                    end
                end

                OP_32: begin
                    if (is_mext) begin
                        muldiv_start = 1;
                        muldiv_op    = {1'b0, funct3};
                        is_word_op   = 1;
                    end else begin
                        alu_op    = derived_alu_op;
                        alu_src_a = 2'b00;
                        alu_src_b = 1'b0;
                        is_word_op = 1;
                    end
                end

                OP_IMM: begin
                    alu_op    = derived_alu_op;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                    is_word_op = 0;
                end

                OP_IMM_32: begin
                    alu_op    = derived_alu_op;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                    is_word_op = 1;
                end

                LUI: begin
                    alu_op    = ALU_PASSB;
                    alu_src_a = 2'b10;
                    alu_src_b = 1'b1;
                end

                AUIPC: begin
                    alu_op    = ALU_ADD;
                    alu_src_a = 2'b01;
                    alu_src_b = 1'b1;
                end

                JALR: begin
                    alu_op    = ALU_ADD;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                end

                LOAD, LOAD_FP: begin
                    alu_op    = ALU_ADD;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                end

                STORE, STORE_FP: begin
                    alu_op    = ALU_ADD;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                end

                AMO: begin
                    alu_op    = ALU_ADD;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1; // imm = 0 for AMO
                end

                OP_FP: begin
                    fpu_start  = 1;
                    fpu_single = (fmt == 2'b00);
                    fpu_rm     = resolved_rm;
                    case (funct5)
                        5'b00000: fpu_op = 5'b00000; // FADD
                        5'b00001: fpu_op = 5'b00001; // FSUB
                        5'b00010: fpu_op = 5'b00010; // FMUL
                        5'b00011: fpu_op = 5'b00011; // FDIV
                        5'b01011: fpu_op = 5'b00100; // FSQRT
                        5'b00100: begin // FSGNJ/FSGNJN/FSGNJX
                            case (funct3)
                                3'b000: fpu_op = 5'b01001;
                                3'b001: fpu_op = 5'b01010;
                                3'b010: fpu_op = 5'b01011;
                                default: fpu_op = 5'b01001;
                            endcase
                        end
                        5'b00101: begin // FMIN/FMAX
                            fpu_op = (funct3 == 3'b000) ? 5'b01100 : 5'b01101;
                        end
                        5'b11000: begin // FCVT.W/WU/L/LU from float
                            case (rs2_addr)
                                5'b00000: fpu_op = 5'b01110; // FCVT.W
                                5'b00001: fpu_op = 5'b01111; // FCVT.WU
                                5'b00010: fpu_op = 5'b10000; // FCVT.L
                                5'b00011: fpu_op = 5'b10001; // FCVT.LU
                                default:  fpu_op = 5'b01110;
                            endcase
                        end
                        5'b11010: begin // FCVT.S/D from int
                            case (rs2_addr)
                                5'b00000: fpu_op = 5'b10010; // FCVT.S/D.W
                                5'b00001: fpu_op = 5'b10011; // FCVT.S/D.WU
                                5'b00010: fpu_op = 5'b10100; // FCVT.S/D.L
                                5'b00011: fpu_op = 5'b10101; // FCVT.S/D.LU
                                default:  fpu_op = 5'b10010;
                            endcase
                        end
                        5'b01000: fpu_op = 5'b10110; // FCVT.S.D / FCVT.D.S
                        5'b11100: begin // FMV.X.W/D or FCLASS
                            fpu_op = (funct3 == 3'b001) ? 5'b11100 : 5'b10111; // FCLASS : FMV.X
                        end
                        5'b11110: fpu_op = 5'b11000; // FMV.W.X / FMV.D.X
                        5'b10100: begin // FEQ/FLT/FLE
                            case (funct3)
                                3'b010: fpu_op = 5'b11001; // FEQ
                                3'b001: fpu_op = 5'b11010; // FLT
                                3'b000: fpu_op = 5'b11011; // FLE
                                default: fpu_op = 5'b11001;
                            endcase
                        end
                        default: fpu_op = 5'b00000;
                    endcase
                end

                MADD: begin
                    fpu_start  = 1;
                    fpu_op     = 5'b00101;
                    fpu_single = (fmt == 2'b00);
                    fpu_rm     = resolved_rm;
                end
                MSUB: begin
                    fpu_start  = 1;
                    fpu_op     = 5'b00110;
                    fpu_single = (fmt == 2'b00);
                    fpu_rm     = resolved_rm;
                end
                NMSUB: begin
                    fpu_start  = 1;
                    fpu_op     = 5'b01000;
                    fpu_single = (fmt == 2'b00);
                    fpu_rm     = resolved_rm;
                end
                NMADD: begin
                    fpu_start  = 1;
                    fpu_op     = 5'b00111;
                    fpu_single = (fmt == 2'b00);
                    fpu_rm     = resolved_rm;
                end

                default: ; // BRANCH, JAL, FENCE, SYSTEM — no ALU needed in EXECUTE
            endcase
        end

        MEMORY: begin
            case (opcode)
                LOAD: begin
                    mem_read     = 1;
                    mem_size     = funct3[1:0] == 2'b11 ? 3'b011 : {1'b0, funct3[1:0]};
                    mem_unsigned = funct3[2];
                end
                STORE: begin
                    mem_write = 1;
                    mem_size  = {1'b0, funct3[1:0]};
                end
                LOAD_FP: begin
                    mem_read     = 1;
                    mem_size     = (funct3 == 3'b010) ? 3'b010 : 3'b011; // FLW=word, FLD=double
                    mem_unsigned = 1;
                end
                STORE_FP: begin
                    mem_write = 1;
                    mem_size  = (funct3 == 3'b010) ? 3'b010 : 3'b011;
                end
                AMO: begin
                    amo_word = (funct3 == 3'b010);
                    mem_size = (funct3 == 3'b010) ? 3'b010 : 3'b011;
                    if (is_lr) begin
                        mem_read = 1;
                    end else if (is_sc) begin
                        mem_write = 1;
                    end else begin
                        // AMO read-modify-write
                        amo_op = derived_amo_op;
                        case (mem_cycle)
                            2'd0: begin
                                mem_read = 1;
                            end
                            2'd1: begin
                                mem_write = 1;
                                amo_en    = 1;
                            end
                            2'd2: ; // transition to WRITEBACK
                        endcase
                    end
                end
                default: ;
            endcase
        end

        WRITEBACK: begin
            if (is_ecall_ebreak) begin
                halt     = 1;
                pc_write = 0;
            end else if (is_mret) begin
                pc_write = 1;
                pc_src   = 2'b11; // mepc
            end else begin
                pc_write = 1;

                case (opcode)
                    OP, OP_32: begin
                        if (is_mext) begin
                            wb_src    = 3'b101; // muldiv
                            reg_write = 1;
                        end else begin
                            wb_src    = 3'b000; // alu
                            reg_write = 1;
                        end
                    end
                    OP_IMM, OP_IMM_32: begin
                        wb_src    = 3'b000;
                        reg_write = 1;
                    end
                    LUI, AUIPC: begin
                        wb_src    = 3'b000;
                        reg_write = 1;
                    end
                    JAL: begin
                        wb_src    = 3'b011; // pc+4
                        reg_write = 1;
                        pc_src    = 2'b01;  // branch_target
                    end
                    JALR: begin
                        wb_src    = 3'b011;
                        reg_write = 1;
                        pc_src    = 2'b10;  // alu result
                    end
                    BRANCH: begin
                        pc_src = branch_taken ? 2'b01 : 2'b00;
                    end
                    LOAD: begin
                        wb_src    = 3'b001; // mem
                        reg_write = 1;
                    end
                    LOAD_FP: begin
                        wb_src       = 3'b001;
                        fp_reg_write = 1;
                    end
                    STORE, STORE_FP: begin
                        // no register write
                    end
                    AMO: begin
                        wb_src    = 3'b001; // mem (old value)
                        reg_write = 1;
                    end
                    OP_FP: begin
                        fflags_write = 1;
                        // Determine destination register file
                        if (funct5 == 5'b11000 || funct5 == 5'b10100 ||
                            (funct5 == 5'b11100)) begin
                            // FCVT to int, FEQ/FLT/FLE, FCLASS, FMV.X → int regfile
                            wb_src    = 3'b010;
                            reg_write = 1;
                        end else begin
                            // Everything else → fp regfile
                            wb_src       = 3'b010;
                            fp_reg_write = 1;
                        end
                    end
                    MADD, MSUB, NMSUB, NMADD: begin
                        wb_src       = 3'b010;
                        fp_reg_write = 1;
                        fflags_write = 1;
                    end
                    SYSTEM: begin
                        if (is_csr) begin
                            wb_src    = 3'b100; // csr
                            reg_write = 1;
                            csr_write = 1;
                            case (funct3[1:0])
                                2'b01: csr_op = 2'b00; // CSRRW/CSRRWI
                                2'b10: csr_op = 2'b01; // CSRRS/CSRRSI
                                2'b11: csr_op = 2'b10; // CSRRC/CSRRCI
                                default: csr_op = 2'b00;
                            endcase
                            // Suppress CSR write for CSRRS/CSRRC with rs1=0
                            if ((funct3[1:0] == 2'b10 || funct3[1:0] == 2'b11) &&
                                (funct3[2] ? (imm_i[4:0] == 5'b0) : (imm_i[19:15] == 5'b0)))
                                csr_write = 0;
                        end
                    end
                    MISC_MEM: begin
                        // FENCE/FENCE.I — NOP, just advance PC
                    end
                    default: ;
                endcase
            end
        end

        FP_EXEC: begin
            // Stall until fpu_done
        end

        MULDIV_EXEC: begin
            // Stall until muldiv_done
        end
    endcase
end

endmodule
