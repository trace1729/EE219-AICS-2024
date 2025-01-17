`include "v_defines.v"


module v_rvcpu(
    input                       clk,
    input                       rst,
    input   [`VINST_BUS]        inst ,

    input   [`SREG_BUS]         vec_rs1_data,
	output            	        vec_rs1_r_ena,
	output  [`SREG_ADDR_BUS]   	vec_rs1_r_addr,

    output                      vram_r_ena,
    output  [`VRAM_ADDR_BUS]    vram_r_addr,
    input   [`VRAM_DATA_BUS]    vram_r_data,

    output                      vram_w_ena,
    output  [`VRAM_ADDR_BUS]    vram_w_addr,
    output  [`VRAM_DATA_BUS]    vram_w_data,
    output  [`VRAM_DATA_BUS]    vram_w_mask
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


endmodule
