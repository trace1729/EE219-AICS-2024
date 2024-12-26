// =======================================
// You need to finish this module
// =======================================

`include "define_rv32v.v"

module v_id #(
    parameter VLMAX     = 8,
    parameter VALUOP_DW = 5,
    parameter VMEM_DW   = 256,
    parameter VMEM_AW   = 32,
    parameter VREG_DW   = 256,
    parameter VREG_AW   = 5,
    parameter INST_DW   = 32,
    parameter REG_DW    = 32,
    parameter REG_AW    = 5
) (
    input                   clk,
    input                   rst,

    input   [INST_DW-1:0]   inst_i,

    output                  rs1_en_o,
    output  [REG_AW-1:0]    rs1_addr_o,
    input   [REG_DW-1:0]    rs1_dout_i,

    output                  vs1_en_o,
    output  [VREG_AW-1:0]   vs1_addr_o,
    input   [VREG_DW-1:0]   vs1_dout_i,

    output                  vs2_en_o,
    output  [VREG_AW-1:0]   vs2_addr_o,
    input   [VREG_DW-1:0]   vs2_dout_i,

    output  [VALUOP_DW-1:0] valu_opcode_o,
    output  [VREG_DW-1:0]   operand_v1_o,
    output  [VREG_DW-1:0]   operand_v2_o,

    output                  vmem_ren_o,
    output                  vmem_wen_o,
    output  [VMEM_AW-1:0]   vmem_addr_o,
    output  [VMEM_DW-1:0]   vmem_din_o,

    output                  vid_wb_en_o,
    output                  vid_wb_sel_o,
    output  [VREG_AW-1:0]   vid_wb_addr_o
);

localparam VALU_OP_NOP  = 5'd0 ;
localparam VALU_OP_VADD = 5'd1 ;
localparam VALU_OP_VMUL = 5'd2 ;


  wire [6:0] opcode = inst_i[6:0];  // bits 6..0
  wire [2:0] funct3 = inst_i[14:12];  // bits 14..12
  wire [5:0] funct6 = inst_i[31:26];  // bits 31..26
  wire [4:0] rd = inst_i[11:7];

  // Noted that vs1, rs1, imm are in the same location
  wire [4:0] rs1 = inst_i[19:15];  // used for vadd.vx, vmul.vx, or memory base
  wire [4:0] vs1 = inst_i[19:15];  // used for vadd.vx, vmul.vx, or memory base
  wire [4:0] imm = inst_i[19:15];  // used for vadd.vx, vmul.vx, or memory base

  wire [4:0] vs2 = inst_i[24:20];  // typical vector source register

  wire is_vle32 = (opcode == `OPCODE_VL) && (funct3 == `WIDTH_VLE32) && (funct6 == `FUNCT6_VLE32);
  wire is_vse32 = (opcode == `OPCODE_VS) && (funct3 == `WIDTH_VSE32) && (funct6 == `FUNCT6_VSE32);

  wire is_vadd_vv = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVV) && (funct6 == `FUNCT6_VADD);
  wire is_vadd_vi = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVI) && (funct6 == `FUNCT6_VADD);
  wire is_vadd_vx = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVX) && (funct6 == `FUNCT6_VADD);

  wire is_vmul_vv = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVV) && (funct6 == `FUNCT6_VMUL);
  wire is_vmul_vi = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVI) && (funct6 == `FUNCT6_VMUL);
  wire is_vmul_vx = (opcode == `OPCODE_VEC) && (funct3 == `FUNCT3_IVX) && (funct6 == `FUNCT6_VMUL);

  reg r_rs1_en;
  reg [REG_AW-1:0] r_rs1_addr;
  reg r_vs1_en, r_vs2_en;
  reg [VREG_AW-1:0] r_vs1_addr, r_vs2_addr;

  reg [VALUOP_DW-1:0] r_valu_opcode;
  reg [VREG_DW-1:0] r_operand_v1, r_operand_v2;

  reg r_vmem_ren, r_vmem_wen;
  reg [VMEM_AW-1:0] r_vmem_addr;
  reg [VMEM_DW-1:0] r_vmem_din;

  reg               r_vid_wb_en;
  reg               r_vid_wb_sel;
  reg [VREG_AW-1:0] r_vid_wb_addr;


  always @(*) begin
    // Default = no operation
    r_rs1_en      = 1'b0;
    r_rs1_addr    = {REG_AW{1'b0}};
    r_vs1_en      = 1'b0;
    r_vs1_addr    = {VREG_AW{1'b0}};
    r_vs2_en      = 1'b0;
    r_vs2_addr    = {VREG_AW{1'b0}};

    r_valu_opcode = VALU_OP_NOP;  // from your localparam
    r_operand_v1  = {VREG_DW{1'b0}};
    r_operand_v2  = {VREG_DW{1'b0}};

    r_vmem_ren    = 1'b0;
    r_vmem_wen    = 1'b0;
    r_vmem_addr   = {VMEM_AW{1'b0}};
    r_vmem_din    = {VMEM_DW{1'b0}};

    r_vid_wb_en   = 1'b0;
    r_vid_wb_sel  = 1'b0;
    r_vid_wb_addr = {VREG_AW{1'b0}};

    // ------ Vector Load ------
    if (is_vle32) begin
      r_vmem_ren    = 1'b1;  // read from memory
      r_vid_wb_en   = 1'b1;  // write back loaded data
      r_vid_wb_sel  = 1'b1;  // 1 => data from memory
      r_vid_wb_addr = rd;  // vector dest register = rd

      // Address from scalar rs1
      r_rs1_en      = 1'b1;
      r_rs1_addr    = rs1;
      r_vmem_addr   = rs1_dout_i;

      // ------ Vector Store ------
    end else if (is_vse32) begin
      r_vmem_wen = 1'b1;
      // No register file write-back for a store
      // Address from scalar rs1
      r_rs1_en   = 1'b1;
      r_rs1_addr = rs1;
      // The data to store is from vs2
      r_vs2_en   = 1'b1;
      r_vs2_addr = vs2;
      r_vmem_addr = rs1_dout_i; // set the memory address for write
      r_vmem_din     = vs2_dout_i;

      // ------ vadd.vv ------
    end else if (is_vadd_vv) begin
      r_vs1_en      = 1'b1;
      r_vs1_addr    = vs1;  // NOTE: for .vv, some specs say vs1=bits[19:15], check carefully
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;
      r_valu_opcode = VALU_OP_VADD;

      r_vid_wb_en   = 1'b1;  // ALU result
      r_vid_wb_sel  = 1'b0;  // 0 => from ALU
      r_vid_wb_addr = rd;

      // ------ vadd.vi ------
    end else if (is_vadd_vi) begin
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;
      r_valu_opcode = VALU_OP_VADD;

      r_vid_wb_en   = 1'b1;
      r_vid_wb_sel  = 1'b0;
      r_vid_wb_addr = rd;

      // ------ vadd.vx ------
    end else if (is_vadd_vx) begin
      r_rs1_en      = 1'b1;
      r_rs1_addr    = rs1;
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;

      r_valu_opcode = VALU_OP_VADD;

      r_vid_wb_en   = 1'b1;
      r_vid_wb_sel  = 1'b0;
      r_vid_wb_addr = rd;

      // ------ vmul.vv ------
    end else if (is_vmul_vv) begin
      r_vs1_en      = 1'b1;
      r_vs1_addr    = rs1;
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;

      r_valu_opcode = VALU_OP_VMUL;

      r_vid_wb_en   = 1'b1;
      r_vid_wb_sel  = 1'b0;
      r_vid_wb_addr = rd;

      // ------ vmul.vi ------
    end else if (is_vmul_vi) begin
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;
      r_valu_opcode = VALU_OP_VMUL;

      r_vid_wb_en   = 1'b1;
      r_vid_wb_sel  = 1'b0;
      r_vid_wb_addr = rd;

      // ------ vmul.vx ------
    end else if (is_vmul_vx) begin
      r_rs1_en      = 1'b1;
      r_rs1_addr    = rs1;
      r_vs2_en      = 1'b1;
      r_vs2_addr    = vs2;

      r_valu_opcode = VALU_OP_VMUL;

      r_vid_wb_en   = 1'b1;
      r_vid_wb_sel  = 1'b0;
      r_vid_wb_addr = rd;

    end
    // else default => NOP
  end

  always @(*) begin
    // By default, just forward vector registers
    r_operand_v1 = vs1_dout_i;
    r_operand_v2 = vs2_dout_i;

    // If vadd.vx or vmul.vx => replicate scalar (rs1_dout_i) across each element
    if (is_vadd_vx || is_vmul_vx) begin
      r_operand_v2 = {8{rs1_dout_i}};  // if SEW=32 and VLMAX=8
    end

    // If vadd.vi or vmul.vi => replicate the sign-extended imm
    // as each 32-bit chunk
    if (is_vadd_vi || is_vmul_vi) begin
      reg [31:0] imm32 = {{27{imm[4]}}, imm};
      r_operand_v2 = {8{imm32}};
    end
  end


endmodule

