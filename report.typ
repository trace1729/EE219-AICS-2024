#import "simplepaper.typ": *

#show: project.with(
  title: "EE219 Final Project",
  authors: (
     (
      name: "倪村逍",
      email: "nicx2024@shanghaitech.edu.cn"
    ),
    (
      name: "龚开宸",
      email: "gongkch2024@shanghaitech.edu.cn"
    )
  ),
)

= Neural-Networks

== LeNet-like Model implemented in C (scalar version)

1.memory access module：Memory access interface is implemented through `read_memory` and `write_memory` functions. These functions utilize the `uint8_t` type for address operations, ensuring compatibility with the hardware platform. The `read_memory` function directly accesses memory through address conversion, while the `write_memory` function implements byte-by-byte data writing.

```C
uint8_t* read_memory(uint32_t addr) {
    return (uint8_t*)(uintptr_t)addr;
}

void write_memory(uint32_t addr, uint8_t* data, size_t size) {
    uint8_t* memory = (uint8_t*)(uintptr_t)addr;
    for (size_t i = 0; i < size; ++i) {
        memory[i] = data[i];
    }
}
```

2.debug module：The `print_tensor` function provides visualization capabilities for tensor data. This function utilizes the `int8_t` data type for storing actual values and is capable of displaying the tensor's shape along with its first 20 values.

```C
void print_tensor(const char* name, int8_t* data, int channels, int height, int width) {
    printf("\n=== %s ===\n", name);
    printf("Shape: [1, %d, %d, %d]\n", channels, height, width);
    printf("First few values: ");
    for (int i = 0; i < 20 && i < channels * height * width; i++) {
        printf("%d ", data[i]);
    }
    printf("\n");
    printf("================\n\n");
}
}
```
3.quantization module：The quantization process is implemented through the `quantize` function, which replaces floating-point division with power-of-two shift operations. This function accepts a 32-bit integer input value and a scaling factor power, producing an 8-bit quantized output.

```C
int8_t quantize(int32_t value, int scale_power) {
    int scale = 1 << scale_power;
    return (int8_t)((value + (scale >> 1)) / scale);
}

```

4.activation funtion（relu）：The `relu_fc` function implements the ReLU (Rectified Linear Unit) activation operation specifically for fully connected layers. This implementation is notable for its in-place modification of `int8_t` data, where negative values are set to zero. It's important to note that while this ReLU implementation is dedicated to fully connected layers, the convolutional layers incorporate their ReLU activation directly within their implementation.

```C
void relu_fc(int8_t* data, int size) {
    for (int i = 0; i < size; i++) {
        if (data[i] < 0) {
            data[i] = 0;
        }
    }
}
```

5.Convolutional Layer： The `conv2d` function implements two-dimensional convolution operations. This implementation processes quantized inputs and weights (both using int8_t data type) and produces outputs that are quantized and processed through ReLU activation. The function accommodates multi-channel input and output configurations, executing fundamental sliding window convolution operations.

```C
void conv2d(uint32_t input_addr, uint32_t weight_addr, uint32_t scale_addr, uint32_t output_addr,
            int input_channels, int output_channels, int kernel_size, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int8_t scale_power = *read_memory(scale_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;
    
    int padding = 0;
    int calc_count = 0;

    print_tensor("Conv2D Input", input, input_channels, input_size, input_size);
    
    for (int oc = 0; oc < output_channels; ++oc) {
        for (int oy = 0; oy < output_size; ++oy) {
            for (int ox = 0; ox < output_size; ++ox) {
                int32_t sum = 0;
                
                if (calc_count < 10) {
                    printf("\nCalculation #%d (oc=%d, oy=%d, ox=%d):\n", calc_count, oc, oy, ox);
                }
                
                for (int ic = 0; ic < input_channels; ++ic) {
                    for (int ky = 0; ky < kernel_size; ++ky) {
                        for (int kx = 0; kx < kernel_size; ++kx) {
                            int iy = oy + ky - padding;
                            int ix = ox + kx - padding;
                            
                            if (iy >= 0 && iy < input_size && ix >= 0 && ix < input_size) {
                                int input_idx = ((ic * input_size + iy) * input_size) + ix;
                                int weight_idx = (((oc * input_channels + ic) * kernel_size + ky) * kernel_size) + kx;
                                
                                if (calc_count < 10) {
                                    printf("  ic=%d, ky=%d, kx=%d: ", ic, ky, kx);
                                    printf("input[%d]=%d * weight[%d]=%d\n", 
                                           input_idx, input[input_idx], 
                                           weight_idx, weights[weight_idx]);
                                }
                                
                                sum += input[input_idx] * weights[weight_idx];
                            }
                        }
                    }
                }
                
                if (calc_count < 10) {
                    printf("Final sum = %d\n", sum);
                }

                if(sum < 0) {
                    sum = 0;
                }
                
                int output_idx = (oc * output_size + oy) * output_size + ox;
                output[output_idx] = quantize(sum, scale_power);
                calc_count++;
            }
        }
    }
    print_tensor("Conv2D Output", output, output_channels, output_size, output_size);
}
```

6.Pooling Layer： The `maxpool2d` function executes maximum pooling operations using a 2×2 window configuration. This implementation maintains channel dimensionality while reducing spatial dimensions by half. The implementation methodology closely mirrors that of the conv2d function, utilizing a similar nested loop structure.

```C
void maxpool2d(uint32_t input_addr, uint32_t output_addr, int channels, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;

    printf("\nRunning MaxPool2D: input_addr=%x, output_addr=%x\n", input_addr, output_addr);
    
    print_tensor("MaxPool2D Input", input, channels, input_size, input_size);

    for (int c = 0; c < channels; ++c) {
        for (int oy = 0; oy < output_size; ++oy) {
            for (int ox = 0; ox < output_size; ++ox) {
                int max_val = -128;
                for (int ky = 0; ky < 2; ++ky) {
                    for (int kx = 0; kx < 2; ++kx) {
                        int iy = oy * 2 + ky;
                        int ix = ox * 2 + kx;
                        int input_idx = (c * input_size + iy) * input_size + ix;
                        if (input[input_idx] > max_val) {
                            max_val = input[input_idx];
                        }
                    }
                }
                int output_idx = (c * output_size + oy) * output_size + ox;
                output[output_idx] = max_val;
            }
        }
    }
    
    print_tensor("MaxPool2D Output", output, channels, output_size, output_size);
}
```

7.Fully Connected Layer： The `fully_connected` function implements the operations for a fully connected layer. This implementation supports optional bias terms using the `int16_t` data type to accommodate a broader numerical range and incorporates quantization operations. The layer computes the final output by multiplying all input vectors with their corresponding weight vectors.

```C
void fully_connected(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, uint32_t scale_addr,
                     uint32_t output_addr, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int16_t* bias = (int16_t*)read_memory(bias_addr);
    int8_t scale_power = *read_memory(scale_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;

    printf("\nRunning Fully Connected: input_addr=%x, weight_addr=%x, bias_addr=%x, scale_addr=%x, output_addr=%x, scale_power=%d\n",
           input_addr, weight_addr, bias_addr, scale_addr, output_addr, scale_power);
    
    printf("\n=== FC Input ===\n");
    printf("Size: %d\n", input_size);
    printf("First few values: ");
    for (int i = 0; i < 10 && i < input_size; i++) {
        printf("%d ", input[i]);
    }
    printf("\n================\n");

    for (int o = 0; o < output_size; ++o) {
        int32_t sum = bias ? bias[o] : 0;
        for (int i = 0; i < input_size; ++i) {
            sum += input[i] * weights[o * input_size + i];
        }
        output[o] = quantize(sum, scale_power);
    }
    
    printf("\n=== FC Output ===\n");
    printf("Size: %d\n", output_size);
    printf("Values: ");
    for (int i = 0; i < output_size && i < 10; i++) {
        printf("%d ", output[i]);
    }
    printf("\n================\n");
}
```


== The inference result (scalar version)

#figure(
  image("img/iShot_2025-01-16_22.29.33.png", width: 80%),
  caption: [
  ],
)

= Application software

In order to accelerate the inference process, we decide to use verilog to represent different layers of the neural network.

In order to let application be able to utilize the hardware resources, we need to design a set of custom instrucions to instruct processor to use accelerating hardware resources.

We need to integrate custom instructions for `conv2d`, `maxpool2d`, and `fully_connected` layers into your C program.

Below is the implementation for each operation using custom instructions and `__asm__ __volatile__`. Each function will encapsulate the custom instruction(s) to simplify usage and make the program modular.

== Interface Design 


*Steps*
1. *Pack Parameters*: 
   - We'll pack parameters such as `input_channels`, `output_channels`, `kernel_size`, `input_size`, and `output_size` into a single `32-bit` register (`packed1`).
   - We'll then load addresses such as `input_addr`, `weight_addr`, `output_addr` into separate registers.
   
2. *Load Instructions*:
   - We will use `lw` to load these packed parameters and addresses into registers.

3. *Custom Instruction*:
   - Finally, we will use a custom instruction to trigger the AI accelerator to perform the operation (convolution, maxpooling, or fully connected).


*1. `conv2d` Implementation*

```c
void conv2d(uint32_t input_addr, uint32_t weight_addr, uint32_t scale_addr,
            uint32_t output_addr, uint8_t input_channels, uint8_t output_channels,
            uint8_t kernel_size, uint8_t input_size, uint8_t output_size) {
    int null;

    // Packing multiple parameters into a single 32-bit register
    uint32_t packed1 = (input_channels & 0xFF) | 
                       ((output_channels & 0xFF) << 8) | 
                       ((kernel_size & 0xFF) << 12) | 
                       ((output_size & 0xFF) << 16) | 
                       ((input_size & 0xFF) << 24);

    uint32_t packed2 = (output_size & 0xFF) | 
                       ((input_addr & 0xFFFF) << 8) | 
                       ((weight_addr & 0xFFFF) << 24);

    // Load packed parameters and addresses
    __asm__ __volatile__(
        "lw a0, %[packed1]\n"             // Load packed parameters into a0
        "lw a1, %[input_addr]\n"          // Load input address into a1
        "lw a2, %[weight_addr]\n"         // Load weight address into a2
        "lw a3, %[output_addr]\n"         // Load output address into a3
        "lw a4, %[scale_addr]\n"          // Load scale address into a4
        // Custom instruction to initiate operation
        ".insn r 0x77, 0, 0, %[null], %[packed1], %[packed2]"
        : [null] "=r"(null)
        : [packed1] "r"(packed1), [packed2] "r"(packed2),
          [input_addr] "r"(input_addr), [weight_addr] "r"(weight_addr),
          [output_addr] "r"(output_addr), [scale_addr] "r"(scale_addr)
        : "a0", "a1", "a2", "a3", "a4");
}
```

*2. `maxpool2d` Implementation*

```c
void maxpool2d(uint32_t input_addr, uint32_t output_addr, uint8_t channels, 
               uint8_t input_size, uint8_t output_size) {
    int null;

    // Packing multiple parameters into a single 32-bit register
    uint32_t packed = (channels & 0xFF) | 
                      ((input_size & 0xFF) << 8) | 
                      ((output_size & 0xFF) << 16) | 
                      ((input_addr & 0xFFFF) << 24);

    // Load packed parameters and addresses
    __asm__ __volatile__(
        "lw a0, %[packed]\n"             // Load packed parameters into a0
        "lw a1, %[output_addr]\n"        // Load output address into a1
        // Custom instruction to initiate operation
        ".insn r 0x77, 1, 0, %[null], %[packed], a1"
        : [null] "=r"(null)
        : [packed] "r"(packed), [output_addr] "r"(output_addr)
        : "a0", "a1");
}
```

---

*3. `fully_connected` Implementation*

```c
void fully_connected(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, 
                     uint32_t scale_addr, uint32_t output_addr, uint16_t input_size, 
                     uint16_t output_size) {
    int null;

    // Packing parameters into two 32-bit registers
    uint32_t packed1 = (input_size & 0xFFFF) | ((output_size & 0xFFFF) << 16);
    uint32_t packed2 = (input_addr & 0xFFFF) | 
                       ((weight_addr & 0xFFFF) << 16) | 
                       ((bias_addr & 0xFFFF) << 24);

    // Load packed parameters and addresses
    __asm__ __volatile__(
        "lw a0, %[scale_addr]\n"  // Load scaling factor into a0
        "lw a1, %[output_addr]\n" // Load output address into a1
        // Custom instruction to initiate operation
        ".insn r 0x77, 2, 0, %[null], %[packed1], %[packed2]"
        : [null] "=r"(null)
        : [packed1] "r"(packed1), [packed2] "r"(packed2),
          [scale_addr] "r"(scale_addr), [output_addr] "r"(output_addr)
        : "a0", "a1");
}
```


== Using These Functions

Replace the high-level API calls in your code with the corresponding custom instruction wrapper functions. For example:

```c
int main() {
    // Conv1
    SCNN_Conv2D((int8_t *)ADDR_INPUT, (int8_t *)ADDR_WCONV1, *(int8_t *)ADDR_SCONV1,
                (int8_t *)ADDR_OUTCONV1, 3, 12, 5, 32, 28);

    // Pool1
    SCNN_MaxPool2D((int8_t *)ADDR_OUTCONV1, (int8_t *)ADDR_OUTPOOL1, 12, 28, 14);

    // Conv2
    SCNN_Conv2D((int8_t *)ADDR_OUTPOOL1, (int8_t *)ADDR_WCONV2, *(int8_t *)ADDR_SCONV2,
                (int8_t *)ADDR_OUTCONV2, 12, 32, 3, 14, 12);

    // Pool2
    SCNN_MaxPool2D((int8_t *)ADDR_OUTCONV2, (int8_t *)ADDR_OUTPOOL2, 32, 12, 6);

    // FC1
    SCNN_FullyConnected((int8_t *)ADDR_OUTPOOL2, (int8_t *)ADDR_WFC1, NULL, *(int8_t *)ADDR_SFC1,
                        (int8_t *)ADDR_OUTFC1, 32 * 6 * 6, 256);

    // FC2
    SCNN_FullyConnected((int8_t *)ADDR_OUTFC1, (int8_t *)ADDR_WFC2, NULL, *(int8_t *)ADDR_SFC2,
                        (int8_t *)ADDR_OUTFC2, 256, 64);

    // FC3
    SCNN_FullyConnected((int8_t *)ADDR_OUTFC2, (int8_t *)ADDR_WFC3, (int16_t *)ADDR_BFC3,
                        *(int8_t *)ADDR_SFC3, (int8_t *)ADDR_OUTFC3, 64, 10);

    return 0;
}
```

= Hardware

We need to implement the three pre-defined custom instructions in hardware. 
The initial thought is to use systolic array to accelerate the computation process, 
and the sample implementation is shown below. 

```v
module ConvolutionAccelerator (
    input             valid                     ,
    input      [7:0]  col_data [0:9*26*26-1]    , 
    input      [7:0]  kernel   [0:3*3-1]        ,
    input      [7:0]  bias                      , 
    output     [15:0] conv_result [0:26*26-1]   , 
    input             clk                       ,
    input             reset                     ,
    output reg        conv_done
);
    logic [4:0]  cnt ;

    // combine the results from 26 to 1
    logic [15:0] conv_result_com [0:26*1-1][0:26*1-1];
    genvar i ;
    generate
        for (i = 0; i < 26; i = i + 1) begin
            assign conv_result[i*26: (i+1)*26 - 1] = conv_result_com[i];
        end
    endgenerate

    // split the input data
    logic [7:0] col_data_spl [0:26*1-1][0:9*26*1-1];

    genvar j;
    generate
        for (j = 0; j < 26; j = j + 1) begin
            assign col_data_spl[j] = col_data[j*26*9: (j+1)*26*9 - 1];
        end
    endgenerate

    // data for PE in each clock cycle
    logic [7:0] col_data_tmp [0:9*26*1-1];
    always_comb begin
        case (cnt)
            5'b00000: col_data_tmp = col_data_spl[0];
            5'b00001: col_data_tmp = col_data_spl[1];
            5'b00010: col_data_tmp = col_data_spl[2];
            5'b00011: col_data_tmp = col_data_spl[3];
            5'b00100: col_data_tmp = col_data_spl[4];
            5'b00101: col_data_tmp = col_data_spl[5];
            5'b00110: col_data_tmp = col_data_spl[6];
            5'b00111: col_data_tmp = col_data_spl[7];
            5'b01000: col_data_tmp = col_data_spl[8];
            5'b01001: col_data_tmp = col_data_spl[9];
            5'b01010: col_data_tmp = col_data_spl[10];
            5'b01011: col_data_tmp = col_data_spl[11];
            5'b01100: col_data_tmp = col_data_spl[12];
            5'b01101: col_data_tmp = col_data_spl[13];
            5'b01110: col_data_tmp = col_data_spl[14];
            5'b01111: col_data_tmp = col_data_spl[15];
            5'b10000: col_data_tmp = col_data_spl[16];
            5'b10001: col_data_tmp = col_data_spl[17];
            5'b10010: col_data_tmp = col_data_spl[18];
            5'b10011: col_data_tmp = col_data_spl[19];
            5'b10100: col_data_tmp = col_data_spl[20];
            5'b10101: col_data_tmp = col_data_spl[21];
            5'b10110: col_data_tmp = col_data_spl[22];
            5'b10111: col_data_tmp = col_data_spl[23];
            5'b11000: col_data_tmp = col_data_spl[24];
            5'b11001: col_data_tmp = col_data_spl[25];
            default: col_data_tmp = col_data_tmp;
        endcase
    end

    integer k;
    // results from PE in each clock cycle 
    logic [15:0] conv_result_tmp [0:26*1-1];
    always_comb begin
            case (cnt)
                5'b00000: conv_result_com[0] <= conv_result_tmp;
                5'b00001: conv_result_com[1] <= conv_result_tmp;
                5'b00010: conv_result_com[2] <= conv_result_tmp;
                5'b00011: conv_result_com[3] <= conv_result_tmp;
                5'b00100: conv_result_com[4] <= conv_result_tmp;
                5'b00101: conv_result_com[5] <= conv_result_tmp;
                5'b00110: conv_result_com[6] <= conv_result_tmp;
                5'b00111: conv_result_com[7] <= conv_result_tmp;
                5'b01000: conv_result_com[8] <= conv_result_tmp;
                5'b01001: conv_result_com[9] <= conv_result_tmp;
                5'b01010: conv_result_com[10] <= conv_result_tmp;
                5'b01011: conv_result_com[11] <= conv_result_tmp;
                5'b01100: conv_result_com[12] <= conv_result_tmp;
                5'b01101: conv_result_com[13] <= conv_result_tmp;
                5'b01110: conv_result_com[14] <= conv_result_tmp;
                5'b01111: conv_result_com[15] <= conv_result_tmp;
                5'b10000: conv_result_com[16] <= conv_result_tmp;
                5'b10001: conv_result_com[17] <= conv_result_tmp;
                5'b10010: conv_result_com[18] <= conv_result_tmp;
                5'b10011: conv_result_com[19] <= conv_result_tmp;
                5'b10100: conv_result_com[20] <= conv_result_tmp;
                5'b10101: conv_result_com[21] <= conv_result_tmp;
                5'b10110: conv_result_com[22] <= conv_result_tmp;
                5'b10111: conv_result_com[23] <= conv_result_tmp;
                5'b11000: conv_result_com[24] <= conv_result_tmp;
                5'b11001: conv_result_com[25] <= conv_result_tmp;
                default: conv_result_com <= conv_result_com;
            endcase
        end

    PE pe (
        .col_data(col_data_tmp),
        .kernel(kernel),
        .bias(bias),
        .conv_result(conv_result_tmp)
        // .clk(clk),
        // .reset(reset)
    );

    always @(posedge clk) begin
        if (reset) begin
            cnt <= 5'b0;
        end
        else begin
            if (valid == 1'b1) begin
                cnt <= cnt + 1'b1;    
            end else  if (cnt == 5'b11001) begin
                cnt <= 5'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            conv_done <= 1'b0;
        end
        else begin
            if (cnt == 5'b11001) begin
                conv_done <= 1'b1;
            end;
        end
    end

endmodule

// complete the convolution in 4 clock cycles
// 26*26*9 = 6084 
// 26*26 = 13 * 13 * 4 = 676
module PE (
    input [7:0] col_data [0:9*26*1-1], 
    input [7:0] kernel [0:3*3-1],
    input [7:0] bias, 
    output [15:0] conv_result [0:26*1-1]
    // input clk,
    // input reset
);
    integer k;
    genvar i, j;

    logic [15:0] conv_sum [0:9*26*1-1];

    generate
        for (i = 0; i < 26*1; i = i + 1) begin
            for (j = 0; j < 3*3; j = j + 1) begin
                assign conv_sum[i*9 + j] = col_data[i*9 + j] * kernel[j];
            end
            assign conv_result[i] = conv_sum[i*9+0] + conv_sum[i*9+1] + conv_sum[i*9+2] + conv_sum[i*9+3] + conv_sum[i*9+4] + conv_sum[i*9+5] + conv_sum[i*9+6] + conv_sum[i*9+7] + conv_sum[i*9+8] + bias; 
            end
    endgenerate
    
endmodule
```

However, since the CPU is single-cycle, implementing a systolic array is not feasible. An alternative approach could be to load all the weights from memory addresses at once (leveraging large data bandwidth), perform the computations in Verilog, and then save all the results back to memory in bulk (again utilizing the large data bandwidth).

This approach seems like a potential solution for the project. However, due to time constraints, there isn't enough time to explore and implement it fully.

== What this project really means

After consulting with the TA, the project’s actual requirement is to implement a vector processor and use vector instructions to perform CNN computations. That’s the main goal.

=== Implement vetcor processor

1. `rv_cpu`

```verilog
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
wire [`REG_AW-1:0]     v_rs1_addr;
wire [`REG_DW-1:0]     v_rs1_dout;

wire                  vs1_en;
wire [`VREG_AW-1:0]    vs1_addr;
wire [`VREG_DW-1:0]    vs1_dout;

wire                  vs2_en;
wire [`VREG_AW-1:0]    vs2_addr;
wire [`VREG_DW-1:0]    vs2_dout;

wire [`VALUOP_DW-1:0]  valu_opcode;
wire [`VREG_DW-1:0]    operand_v1;
wire [`VREG_DW-1:0]    operand_v2;

wire                  vmem_ren;
wire                  vmem_wen;
wire [`VMEM_AW-1:0]    vmem_addr;
wire [`VMEM_DW-1:0]    vmem_din;

wire                  vid_wb_en;
wire                  vid_wb_sel;
wire [`VREG_AW-1:0]    vid_wb_addr;


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

wire  [`VREG_DW-1:0] valu_result;

v_alu u_v_alu(
    .valu_opcode_i (valu_opcode ),
    .operand_v1_i  (operand_v1  ),
    .operand_v2_i  (operand_v2  ),
    .valu_result_o (valu_result )
);

wire   [`VRAM_DW-1:0]   vmem_dout;

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
wire  [`VREG_AW-1:0]   vwb_addr;
wire  [`VREG_DW-1:0]   vwb_data;

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

```

2. `inst_decode`

```verilog
// =======================================
// You need to finish this module
// =======================================

`include "v_defines.v"

module v_id #(
    parameter VLMAX     = 8,
    parameter VALUOP_DW = 5,
    parameter VMEM_DW   = 512,
    parameter VMEM_AW   = 64,
    parameter VREG_DW   = 512,
    parameter VREG_AW   = 5,
    parameter INST_DW   = 64,
    parameter REG_DW    = 64,
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
  wire [4:0] vs3 = inst_i[11:7];  // typical vector source register

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

  assign rs1_en_o       = r_rs1_en;
  assign rs1_addr_o     = r_rs1_addr;

  assign vs1_en_o       = r_vs1_en;
  assign vs1_addr_o     = r_vs1_addr;

  assign vs2_en_o       = r_vs2_en;
  assign vs2_addr_o     = r_vs2_addr;

  assign valu_opcode_o  = r_valu_opcode;
  assign operand_v1_o   = r_operand_v1;
  assign operand_v2_o   = r_operand_v2;

  assign vmem_ren_o     = r_vmem_ren;
  assign vmem_wen_o     = r_vmem_wen;
  assign vmem_addr_o    = r_vmem_addr;
  assign vmem_din_o     = r_vmem_din;

  assign vid_wb_en_o    = r_vid_wb_en;
  assign vid_wb_sel_o   = r_vid_wb_sel;
  assign vid_wb_addr_o  = r_vid_wb_addr;


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
      r_vs2_addr = vs3;
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

wire [31: 0] v_imm = {{27{imm[4]}}, imm};

  always @(*) begin
    // If vadd.vx or vmul.vx => replicate scalar (rs1_dout_i) across each element
    if (is_vadd_vx || is_vmul_vx) begin
      r_operand_v1 = vs2_dout_i;
      r_operand_v2 = {8{rs1_dout_i}};  // if SEW=32 and VLMAX=8
    end else if (is_vadd_vi || is_vmul_vi) begin
      // If vadd.vi or vmul.vi => replicate the sign-extended imm
      // as each 32-bit chunk
      r_operand_v1 = vs2_dout_i;
      r_operand_v2 = {8{v_imm}};
    end else begin
      // By default, just forward vector registers
      r_operand_v1 = vs1_dout_i;
      r_operand_v2 = vs2_dout_i;
    end
  end


endmodule

```

=== Modify the C code to use vector instruction

due to time constraints, the work is not fully accomplished

```c
#include "trap.h"
#include "model.h"

uint8_t* read_memory(uint32_t addr) {
    return (uint8_t*)(uintptr_t)addr;
}

void write_memory(uint32_t addr, uint8_t* data, size_t size) {
    uint8_t* memory = (uint8_t*)(uintptr_t)addr;
    for (size_t i = 0; i < size; ++i) {
        memory[i] = data[i];
    }
}

static inline int8_t quantize(int32_t value, int scale_power) {
    int scale = 1 << scale_power;
    return (int8_t)((value + (scale >> 1)) / scale);
}

static inline int32_t vector_dot_1d(const int8_t* x, const int8_t* y, int length) {
    int idx = 0;
    int32_t sum = 0;
    while (idx < length) {
        int chunk = (length - idx < 128) ? (length - idx) : 128;
        static int32_t partial_sum[128];
        for (int i = 0; i < chunk; i++) {
            partial_sum[i] = 0;
        }
        asm volatile (
            "vsetvli t0, %2, e8, m1\n\t"
            "vmv.v.i   v2, 0\n\t"
            "vle8.v    v0, (%0)\n\t"
            "vle8.v    v1, (%1)\n\t"
            "vmacc.vv  v2, v0, v1\n\t"
            "vse32.v   v2, (%3)\n\t"
            :
            : "r"(x + idx), "r"(y + idx), "r"(chunk), "r"(partial_sum)
            : "t0", "v0", "v1", "v2", "memory"
        );
        for (int i = 0; i < chunk; i++) {
            sum += partial_sum[i];
        }
        idx += chunk;
    }
    return sum;
}

static inline void gather_input(const int8_t* input, int ic_count, int size, int iy, int ix, int8_t* buf) {
    for (int ic = 0; ic < ic_count; ic++) {
        int idx = (ic * size + iy) * size + ix;
        buf[ic] = input[idx];
    }
}

static inline void gather_weight(const int8_t* weights, int oc, int ic_count, int ksize, int ky, int kx, int8_t* buf) {
    for (int ic = 0; ic < ic_count; ic++) {
        int idx = (((oc * ic_count) + ic) * ksize + ky) * ksize + kx;
        buf[ic] = weights[idx];
    }
}

void conv2d(uint32_t input_addr, uint32_t weight_addr, uint32_t scale_addr, uint32_t output_addr,
            int input_channels, int output_channels, int kernel_size, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int8_t scale_power = *read_memory(scale_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;
    int8_t temp_in[1024];
    int8_t temp_wt[1024];
    int padding = 0;
    for (int oc = 0; oc < output_channels; oc++) {
        for (int oy = 0; oy < output_size; oy++) {
            for (int ox = 0; ox < output_size; ox++) {
                int32_t sum = 0;
                for (int ky = 0; ky < kernel_size; ky++) {
                    for (int kx = 0; kx < kernel_size; kx++) {
                        int iy = oy + ky - padding;
                        int ix = ox + kx - padding;
                        if (iy >= 0 && iy < input_size && ix >= 0 && ix < input_size) {
                            gather_input(input, input_channels, input_size, iy, ix, temp_in);
                            gather_weight(weights, oc, input_channels, kernel_size, ky, kx, temp_wt);
                            sum += vector_dot_1d(temp_in, temp_wt, input_channels);
                        }
                    }
                }
                if (sum < 0) sum = 0;
                int out_idx = (oc * output_size + oy) * output_size + ox;
                output[out_idx] = quantize(sum, scale_power);
            }
        }
    }
}

void maxpool2d(uint32_t input_addr, uint32_t output_addr, int channels, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;
    for (int c = 0; c < channels; c++) {
        for (int oy = 0; oy < output_size; oy++) {
            for (int ox = 0; ox < output_size; ox++) {
                int max_val = -128;
                for (int ky = 0; ky < 2; ky++) {
                    for (int kx = 0; kx < 2; kx++) {
                        int iy = oy * 2 + ky;
                        int ix = ox * 2 + kx;
                        int idx = (c * input_size + iy) * input_size + ix;
                        if (input[idx] > max_val) {
                            max_val = input[idx];
                        }
                    }
                }
                int out_idx = (c * output_size + oy) * output_size + ox;
                output[out_idx] = max_val;
            }
        }
    }
}

void fully_connected(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, uint32_t scale_addr,
                     uint32_t output_addr, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int16_t* bias = (int16_t*)read_memory(bias_addr);
    int8_t scale_power = *read_memory(scale_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;
    for (int o = 0; o < output_size; o++) {
        int32_t sum = bias ? bias[o] : 0;
        sum += vector_dot_1d(input, &weights[o * input_size], input_size);
        if (sum < 0) sum = 0;
        output[o] = quantize(sum, scale_power);
    }
}

void fully_connected_last_layer(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, uint32_t scale_addr,
                                uint32_t output_addr, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int16_t* bias = (int16_t*)read_memory(bias_addr);
    int8_t scale_power = *read_memory(scale_addr);
    int8_t* output = (int8_t*)(uintptr_t)output_addr;
    for (int o = 0; o < output_size; o++) {
        int32_t sum = bias ? bias[o] : 0;
        sum += vector_dot_1d(input, &weights[o * input_size], input_size);
        output[o] = quantize(sum, scale_power);
    }
}

int main() {
    printf("Starting inference...\n");
    conv2d(ADDR_INPUT, ADDR_WCONV1, ADDR_SCONV1, ADDR_OUTCONV1, 3, 12, 5, 32, 28);
    maxpool2d(ADDR_OUTCONV1, ADDR_OUTPOOL1, 12, 28, 14);
    conv2d(ADDR_OUTPOOL1, ADDR_WCONV2, ADDR_SCONV2, ADDR_OUTCONV2, 12, 32, 3, 14, 12);
    maxpool2d(ADDR_OUTCONV2, ADDR_OUTPOOL2, 32, 12, 6);
    fully_connected(ADDR_OUTPOOL2, ADDR_WFC1, 0, ADDR_SFC1, ADDR_OUTFC1, 32 * 6 * 6, 256);
    fully_connected(ADDR_OUTFC1, ADDR_WFC2, 0, ADDR_SFC2, ADDR_OUTFC2, 256, 64);
    fully_connected_last_layer(ADDR_OUTFC2, ADDR_WFC3, ADDR_BFC3, ADDR_SFC3, ADDR_OUTFC3, 64, 10);
    printf("\nInference done. Final output (logits):\n");
    int8_t* p_outfc3 = (int8_t*)(uintptr_t)(ADDR_OUTFC3);
    for (int i = 0; i < 10; i++) {
        printf("Logit[%d] = %d\n", i, (int)p_outfc3[i]);
    }
    printf("\nInference completed.\n");
    return 0;
}
```
