#include "trap.h"
#include "model.h"

// Function to simulate reading memory - 使用uint8因为是地址操作
uint8_t* read_memory(uint32_t addr) {
    return (uint8_t*)(uintptr_t)addr;
}

// Function to simulate writing to memory - 地址操作用uint8
void write_memory(uint32_t addr, uint8_t* data, size_t size) {
    uint8_t* memory = (uint8_t*)(uintptr_t)addr;
    for (size_t i = 0; i < size; ++i) {
        memory[i] = data[i];
    }
}

// Helper function to print tensor data - data改为int8因为是实际数据
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

// Quantization function
int8_t quantize(int32_t value, int scale_power) {
    int scale = 1 << scale_power;
    return (int8_t)((value + (scale >> 1)) / scale);
}

// Convolution function - 保持地址为uint32，数据为int8
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

// MaxPooling function - 地址用uint32，数据用int8
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

// Fully connected layer - 地址用uint32，数据用int8/int16
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
        if(sum < 0){
            sum = 0;
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

void fully_connected_last_layer(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, uint32_t scale_addr,
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
    int8_t *p_outfc3 = (int8_t *)(uintptr_t)(ADDR_OUTFC3);
    for(int i = 0; i < 10; i++) {
        printf("Logit[%d] = %d\n", i, (int)p_outfc3[i]);
    }

    printf("\nInference completed.\n");
    return 0;
}