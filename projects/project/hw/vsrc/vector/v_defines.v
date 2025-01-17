`define VLEN            512
`define SEW             64
`define LMUL            1
`define VLMAX           (`VLEN/`SEW) * `LMUL

`define VINST_BUS       31:0
`define SREG_BUS        63:0
`define SREG_ADDR_BUS   4:0

`define VREG_WIDTH      `VLEN
`define VREG_BUS        `VLEN-1 : 0
`define VREG_ADDR_BUS   4  : 0

`define VMEM_ADDR_BUS   63 : 0
`define VMEM_DATA_BUS   `VLEN-1 : 0

`define VRAM_ADDR_BUS   63 : 0
`define VRAM_DATA_BUS   `VLEN-1 : 0

`define ALU_OP_BUS      7  : 0




// -------------------------------------------------
// RISC-32V Instruction OPCODE
// -------------------------------------------------
`define OPCODE_VL       7'b000_0111 
`define WIDTH_VLE32     3'b110
`define FUNCT6_VLE32    6'b00_0000

`define OPCODE_VS       7'b010_0111
`define WIDTH_VSE32     3'b110
`define FUNCT6_VSE32    6'b00_0000

`define OPCODE_VEC      7'b101_0111 
`define FUNCT3_IVV      3'b000 
`define FUNCT3_IVI      3'b011 
`define FUNCT3_IVX      3'b100 

`define FUNCT6_VADD     6'b00_0000 
`define FUNCT6_VMUL     6'b10_0101 
`define VALUOP_DW 5
`define REG_AM 5
`define REG_DW 32
`define VREG_AW 5
`define VREG_DW 512
`define VMEM_AW 64
`define VMEM_DW 512
`define VRAM_AW 64
`define VRAM_DW 512