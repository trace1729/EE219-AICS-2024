// =======================================
// You need to finish this module
// =======================================

module rvcpu_two_issue #(
    parameter PC_START  = 32'h8000_0000, 
    parameter ISSUE_NUM = 2,
    parameter INST_DW   = 32,
    parameter INST_AW   = 32,
    parameter MEM_DW    = 32,
    parameter MEM_AW    = 32,
    parameter RAM_DW    = 32,
    parameter RAM_AW    = 32,
    parameter REG_DW    = 32,
    parameter REG_AW    = 5,
    parameter ALUOP_DW  = 5,

    parameter SEW       = 32, 
    parameter VLMAX     = 8,
    parameter VALUOP_DW = 5,
    parameter VREG_DW   = 256,
    parameter VREG_AW   = 5,
    parameter VMEM_DW   = 256,
    parameter VMEM_AW   = 32,
    parameter VRAM_DW   = 256,
    parameter VRAM_AW   = 32
)(
    input                           clk,
    input                           rst,

    output                          inst_en_o,
    output  [INST_AW-1:0]           inst_addr_o,
    input   [INST_DW*ISSUE_NUM-1:0] inst_i,

    output                          ram_ren_o,
    output                          ram_wen_o,
    output  [RAM_AW-1:0]            ram_addr_o,
    output  [RAM_DW-1:0]            ram_mask_o,
    output  [RAM_DW-1:0]            ram_din_o,
    input   [RAM_DW-1:0]            ram_dout_i,

    output                          vram_ren_o,
    output                          vram_wen_o,
    output  [VRAM_AW-1:0]           vram_addr_o,
    output  [VRAM_DW-1:0]           vram_mask_o,
    output  [VRAM_DW-1:0]           vram_din_o,
    input   [VRAM_DW-1:0]           vram_dout_i
);

wire control_en;

wire [INST_AW-1:0] control_pc;
wire [INST_AW-1:0] current_pc;
wire [ISSUE_NUM*INST_DW-1:0] inst_o;

wire [INST_DW-1:0] inst_0 = inst_o[31: 0]; // for scalar
wire [INST_DW-1:0] inst_1 = inst_o[63: 32]; // for vector


mi_inst_fetch u_mi_inst_fetch(
    .clk          (clk          ),
    .rst          (rst          ),
    .control_en_i (control_en ),
    .control_pc_i (control_pc ),
    .current_pc_o (current_pc ),
    .inst_en_o    (inst_en_o    ),
    .inst_addr_o  (inst_addr_o  ),
    .inst_i       (inst_i       ),
    .inst_o       (inst_o       )
);

// -- Wires connected to u_v_id --
wire                  v_rs1_en;
wire [REG_AW-1:0]     v_rs1_addr;
wire [REG_DW-1:0]     v_rs1_dout;

wire                  vs1_en;
wire [VREG_AW-1:0]    vs1_addr;
wire [VREG_DW-1:0]    vs1_dout;

wire                  vs2_en;
wire [VREG_AW-1:0]    vs2_addr;
wire [VREG_DW-1:0]    vs2_dout;

wire [VALUOP_DW-1:0]  valu_opcode;
wire [VREG_DW-1:0]    operand_v1;
wire [VREG_DW-1:0]    operand_v2;

wire                  vmem_ren;
wire                  vmem_wen;
wire [VMEM_AW-1:0]    vmem_addr;
wire [VMEM_DW-1:0]    vmem_din;

wire                  vid_wb_en;
wire                  vid_wb_sel;
wire [VREG_AW-1:0]    vid_wb_addr;


v_id u_v_id(
    .clk           (clk           ),
    .rst           (rst           ),
    .inst_i        (inst_1        ),
    .rs1_en_o      (v_rs1_en      ),
    .rs1_addr_o    (v_rs1_addr    ),
    .rs1_dout_i    (v_rs1_dout    ),
    .vs1_en_o      (vs1_en      ),
    .vs1_addr_o    (vs1_addr    ),
    .vs1_dout_i    (vs1_dout    ),
    .vs2_en_o      (vs2_en      ),
    .vs2_addr_o    (vs2_addr    ),
    .vs2_dout_i    (vs2_dout    ),
    .valu_opcode_o (valu_opcode ),
    .operand_v1_o  (operand_v1  ),
    .operand_v2_o  (operand_v2  ),
    .vmem_ren_o    (vmem_ren    ),
    .vmem_wen_o    (vmem_wen    ),
    .vmem_addr_o   (vmem_addr   ),
    .vmem_din_o    (vmem_din    ),
    .vid_wb_en_o   (vid_wb_en   ),
    .vid_wb_sel_o  (vid_wb_sel  ),
    .vid_wb_addr_o (vid_wb_addr )
);

wire  [VREG_DW-1:0] valu_result;

v_alu u_v_alu(
    .valu_opcode_i (valu_opcode ),
    .operand_v1_i  (operand_v1  ),
    .operand_v2_i  (operand_v2  ),
    .valu_result_o (valu_result )
);

wire   [VRAM_DW-1:0]   vmem_dout;

v_mem_access u_v_mem_access(
    .clk         (clk         ),
    .rst         (rst         ),
    .vmem_ren_i  (vmem_ren  ),
    .vmem_wen_i  (vmem_wen  ),
    .vmem_addr_i (vmem_addr ),
    .vmem_din_i  (vmem_din  ),
    .vmem_dout_o (vmem_dout ),
    .vram_ren_o  (vram_ren_o  ),
    .vram_wen_o  (vram_wen_o  ),
    .vram_addr_o (vram_addr_o ),
    .vram_mask_o (vram_mask_o ),
    .vram_din_o  (vram_din_o  ),
    .vram_dout_i (vram_dout_i )
);


wire                  vwb_en;
wire  [VREG_AW-1:0]   vwb_addr;
wire  [VREG_DW-1:0]   vwb_data;

v_wb u_v_wb(
    .clk           (clk           ),
    .rst           (rst           ),
    .vid_wb_en_i   (vid_wb_en  ),
    .vid_wb_sel_i  (vid_wb_sel  ),
    .vid_wb_addr_i (vid_wb_addr ),
    .valu_result_i (valu_result ),
    .vmem_result_i (vmem_dout  ),
    .vwb_en_o      (vwb_en      ),
    .vwb_addr_o    (vwb_addr    ),
    .vwb_data_o    (vwb_data    )
);


v_regfile u_v_regfile(
    .clk        (clk        ),
    .rst        (rst        ),
    .vwb_en_i   (vwb_en   ),
    .vwb_addr_i (vwb_addr ),
    .vwb_data_i (vwb_data ),
    .vs1_en_i   (vs1_en   ),
    .vs1_addr_i (vs1_addr ),
    .vs1_data_o (vs1_dout ),
    .vs2_en_i   (vs2_en   ),
    .vs2_addr_i (vs2_addr ),
    .vs2_data_o (vs2_dout )
);

// below is scalar pipeline

wire    [INST_DW-1:0]   inst            ;

wire    [ALUOP_DW-1:0]  alu_opcode      ;
wire    [REG_DW-1:0]    operand_1       ;
wire    [REG_DW-1:0]    operand_2       ;
wire                    branch_en       ;
wire    [INST_AW-1:0]   branch_offset   ;
wire                    jump_en         ;
wire    [INST_AW-1:0]   jump_offset     ;
wire                    mem_ren         ;
wire                    mem_wen         ;
wire                    id_wb_en        ;
wire                    id_wb_sel       ;
wire    [REG_AW-1:0]    id_wb_addr      ;

wire                    control_en      ;
wire    [INST_AW-1:0]   control_pc      ;
wire    [INST_AW-1:0]   current_pc      ;
wire    [REG_DW-1:0]    alu_result      ;

wire    [MEM_AW-1:0]    mem_addr        ;
wire    [MEM_DW-1:0]    mem_dout        ;
wire    [MEM_DW-1:0]    mem_din         ;

wire                    wb_en           ;
wire    [REG_AW-1:0]    wb_addr         ;
wire    [REG_DW-1:0]    wb_data         ;
wire                    rs1_en          ;
wire    [REG_AW-1:0]    rs1_addr        ;
wire    [REG_DW-1:0]    rs1_data        ;
wire                    rs2_en          ;
wire    [REG_AW-1:0]    rs2_addr        ;
wire    [REG_DW-1:0]    rs2_data        ;

mi2_regfile u_mi2_regfile(
    .clk            (clk            ),
    .rst            (rst            ),
    .is1_wb_en_i    (wb_en    ),
    .is1_wb_addr_i  (wb_addr  ),
    .is1_wb_data_i  (wb_data  ),
    .is1_rs1_en_i   (rs1_en   ),
    .is1_rs1_addr_i (rs1_addr ),
    .is1_rs1_data_o (rs1_data ),
    .is1_rs2_en_i   (rs2_en   ),
    .is1_rs2_addr_i (rs2_addr ),
    .is1_rs2_data_o (rs2_data ),
    .is2_rs1_en_i   (v_rs1_en   ),
    .is2_rs1_addr_i (v_rs1_addr ),
    .is2_rs1_data_o (v_rs1_dout )
);

always @(posedge clk) begin
    if (inst == 32'h0000006b ) begin
        $finish;
    end
end

si_inst_decode #(
    .INST_DW        ( INST_DW       ),
    .INST_AW        ( INST_AW       ),
    .MEM_AW         ( MEM_AW        ),
    .REG_DW         ( REG_DW        ),
    .REG_AW         ( REG_AW        ),
    .ALUOP_DW       ( ALUOP_DW      )
) SI_ID (
    .clk            ( clk           ),
    .rst            ( rst           ),
    .inst_i         ( inst_0          ),
    .rs1_en_o       ( rs1_en        ),
    .rs1_addr_o     ( rs1_addr      ),
    .rs1_dout_i     ( rs1_data      ),
    .rs2_en_o       ( rs2_en        ),
    .rs2_addr_o     ( rs2_addr      ),
    .rs2_dout_i     ( rs2_data      ),
    .alu_opcode_o   ( alu_opcode    ),
    .operand_1_o    ( operand_1     ),
    .operand_2_o    ( operand_2     ),
    .branch_en_o    ( branch_en     ),
    .branch_offset_o( branch_offset ),
    .jump_en_o      ( jump_en       ),
    .jump_offset_o  ( jump_offset   ),
    .mem_ren_o      ( mem_ren       ),
    .mem_wen_o      ( mem_wen       ),
    .mem_din_o      ( mem_din       ),
    .id_wb_en_o     ( id_wb_en      ),
    .id_wb_sel_o    ( id_wb_sel     ),
    .id_wb_addr_o   ( id_wb_addr    )
);

si_alu #(
    .PC_START       ( PC_START      ),
    .INST_DW        ( INST_DW       ),
    .INST_AW        ( INST_AW       ),
    .REG_DW         ( REG_DW        ),
    .ALUOP_DW       ( ALUOP_DW      )
) SI_ALU (
    .clk            ( clk           ),
    .rst            ( rst           ),
    .alu_opcode_i   ( alu_opcode    ),
    .operand_1_i    ( operand_1     ),
    .operand_2_i    ( operand_2     ),
    .alu_result_o   ( alu_result    ),
    .current_pc_i   ( current_pc    ),
    .branch_en_i    ( branch_en     ),
    .branch_offset_i( branch_offset ),
    .jump_en_i      ( jump_en       ),
    .jump_offset_i  ( jump_offset   ),
    .control_en_o   ( control_en    ),
    .control_pc_o   ( control_pc    )
);

assign mem_addr = alu_result ;

si_mem_access #(
    .MEM_DW         ( MEM_DW        ),
    .MEM_AW         ( MEM_AW        ),
    .RAM_DW         ( RAM_DW        ),
    .RAM_AW         ( RAM_AW        )
) SI_MEM (
    .clk            ( clk           ),
    .rst            ( rst           ),
    .mem_ren_i      ( mem_ren       ),
    .mem_wen_i      ( mem_wen       ),
    .mem_addr_i     ( mem_addr      ),
    .mem_din_i      ( mem_din       ),
    .mem_dout_o     ( mem_dout      ),
    .ram_ren_o      ( ram_ren_o     ),
    .ram_wen_o      ( ram_wen_o     ),
    .ram_addr_o     ( ram_addr_o    ),
    .ram_mask_o     ( ram_mask_o    ),
    .ram_din_o      ( ram_din_o     ),
    .ram_dout_i     ( ram_dout_i    )
);

si_write_back #(
    .REG_DW         ( REG_DW        ),
    .REG_AW         ( REG_AW        )
) SI_WB (
    .clk            ( clk           ),
    .rst            ( rst           ),
    .id_wb_en_i     ( id_wb_en      ),
    .id_wb_addr_i   ( id_wb_addr    ),
    .id_wb_sel_i    ( id_wb_sel     ),
    .alu_result_i   ( alu_result    ),
    .mem_result_i   ( mem_dout      ),
    .wb_en_o        ( wb_en         ),
    .wb_addr_o      ( wb_addr       ),
    .wb_data_o      ( wb_data       )
);



endmodule
