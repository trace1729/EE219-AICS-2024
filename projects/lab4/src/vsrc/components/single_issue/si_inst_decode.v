// =======================================
// You need to finish this module
// =======================================


`include "define_rv32im.v"

module si_inst_decode #(
    parameter INST_DW   = 32,
    parameter INST_AW   = 32,
    parameter MEM_AW    = 32,
    parameter REG_DW    = 32,
    parameter REG_AW    = 5,
    parameter ALUOP_DW  = 5

) (
    input                   clk,
    input                   rst,
    // instruction
    input   [INST_DW-1:0]   inst_i,
    // regfile
    output                  rs1_en_o,
    output  [REG_AW-1:0]    rs1_addr_o,
    input   [REG_DW-1:0]    rs1_dout_i,
    output                  rs2_en_o,
    output  [REG_AW-1:0]    rs2_addr_o,
    input   [REG_DW-1:0]    rs2_dout_i,
    // alu
    output  [ALUOP_DW-1:0]  alu_opcode_o,
    output  [REG_DW-1:0]    operand_1_o,
    output  [REG_DW-1:0]    operand_2_o,
    output                  branch_en_o,
    output  [INST_AW-1:0]   branch_offset_o,
    output                  jump_en_o,
    output  [INST_AW-1:0]   jump_offset_o,
    // mem-access
    output                  mem_ren_o,
    output                  mem_wen_o,
    output  [INST_DW-1:0]   mem_din_o,
    // write-back
    output                  id_wb_en_o,
    output                  id_wb_sel_o,
    output  [REG_AW-1:0]    id_wb_addr_o 
);

localparam ALU_OP_NOP   = 5'd0 ;
localparam ALU_OP_ADD   = 5'd1 ;
localparam ALU_OP_MUL   = 5'd2 ;
localparam ALU_OP_BNE   = 5'd3 ;
localparam ALU_OP_JAL   = 5'd4 ;
localparam ALU_OP_LUI   = 5'd5 ;
localparam ALU_OP_AUIPC = 5'd6 ;
localparam ALU_OP_AND   = 5'd7 ;
localparam ALU_OP_SLL   = 5'd8 ;
localparam ALU_OP_SLT   = 5'd9 ;
localparam ALU_OP_BLT   = 5'd10 ;

 // Extract fields from instruction
    wire [6:0] opcode  = inst_i[6:0];
    wire [2:0] funct3  = inst_i[14:12];
    wire [6:0] funct7  = inst_i[31:25];
    wire [4:0] rs1     = inst_i[19:15];
    wire [4:0] rs2     = inst_i[24:20];
    wire [4:0] rd      = inst_i[11:7];
    wire [11:0] imm_i  = inst_i[31:20]; // Immediate for I-type
    wire [11:0] imm_s  = {inst_i[31:25], inst_i[11:7]}; // Immediate for S-type
    wire [12:0] imm_b  = {inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0}; // Immediate for B-type
    wire [31:0] imm_u  = {inst_i[31:12], 12'b0}; // Immediate for U-type
    wire [20:0] imm_j  = {inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0}; // Immediate for J-type

    // Default values
    assign rs1_en_o        = (opcode == `OPCODE_ADD || opcode == `OPCODE_ADDI ||
                               opcode == `OPCODE_LW || opcode == `OPCODE_SW ||
                               opcode == `OPCODE_BNE || opcode == `OPCODE_BLT ||
                               opcode == `OPCODE_JALR || opcode == `OPCODE_MUL ||
                               opcode == `OPCODE_SLL || opcode == `OPCODE_SLTI ||
                               opcode == `OPCODE_AND);
    assign rs2_en_o        = (opcode == `OPCODE_ADD || opcode == `OPCODE_SW ||
                               opcode == `OPCODE_BNE || opcode == `OPCODE_BLT ||
                               opcode == `OPCODE_MUL || opcode == `OPCODE_SLL ||
                               opcode == `OPCODE_AND);
    assign rs1_addr_o      = rs1;
    assign rs2_addr_o      = rs2;

    assign alu_opcode_o    = (opcode == `OPCODE_ADD)  ? ALU_OP_ADD   :
                             (opcode == `OPCODE_ADDI) ? ALU_OP_ADD   :
                             (opcode == `OPCODE_MUL)  ? ALU_OP_MUL   :
                             (opcode == `OPCODE_AND)  ? ALU_OP_AND   :
                             (opcode == `OPCODE_SLL)  ? ALU_OP_SLL   :
                             (opcode == `OPCODE_SLTI) ? ALU_OP_SLT   :
                             (opcode == `OPCODE_BNE)  ? ALU_OP_BNE   :
                             (opcode == `OPCODE_BLT)  ? ALU_OP_BLT   :
                             (opcode == `OPCODE_LUI)  ? ALU_OP_NOP   :
                             (opcode == `OPCODE_AUIPC)? ALU_OP_NOP   :
                             ALU_OP_NOP; // Default

    assign operand_1_o     = rs1_dout_i; // Default to rs1 data
    assign operand_2_o     = (opcode == `OPCODE_ADDI || opcode == `OPCODE_SLTI ||
                               opcode == `OPCODE_LW || opcode == `OPCODE_SW) ? 
                              {{20{imm_i[11]}}, imm_i} : // Immediate for I-type
                              (opcode == `OPCODE_BNE || opcode == `OPCODE_BLT) ? 
                              rs2_dout_i :  // Branch compares rs2
                              rs2_dout_i; // Default rs2 data

    assign branch_en_o     = (opcode == `OPCODE_BNE && rs1_dout_i != rs2_dout_i) ||
                             (opcode == `OPCODE_BLT && $signed(rs1_dout_i) < $signed(rs2_dout_i));
    assign branch_offset_o = {{19{imm_b[12]}}, imm_b}; // Sign-extended branch offset

    assign jump_en_o       = (opcode == `OPCODE_JAL || opcode == `OPCODE_JALR);
    assign jump_offset_o   = (opcode == `OPCODE_JAL) ? {{11{imm_j[20]}}, imm_j} : 
                             (opcode == `OPCODE_JALR) ? (rs1_dout_i + {{20{imm_i[11]}}, imm_i}) :
                             0;

    assign mem_ren_o       = (opcode == `OPCODE_LW);
    assign mem_wen_o       = (opcode == `OPCODE_SW);
    assign mem_din_o       = rs2_dout_i; // SW stores rs2

    assign id_wb_en_o      = (opcode == `OPCODE_ADD || opcode == `OPCODE_ADDI || 
                               opcode == `OPCODE_LW || opcode == `OPCODE_JAL || 
                               opcode == `OPCODE_JALR || opcode == `OPCODE_LUI || 
                               opcode == `OPCODE_AUIPC || opcode == `OPCODE_MUL || 
                               opcode == `OPCODE_SLL || opcode == `OPCODE_AND || 
                               opcode == `OPCODE_SLTI);
    assign id_wb_sel_o     = (opcode == `OPCODE_LW); // Choose memory result
    assign id_wb_addr_o    = rd; // Write-back destinatio

endmodule 
