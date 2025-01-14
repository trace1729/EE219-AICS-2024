#include "trap.h"
#include "model.h"

// Function to simulate reading memory
uint8_t* read_memory(uint32_t addr) {
    return (uint8_t*)(uintptr_t)addr; // Use uintptr_t for correct casting
}

// Function to simulate writing to memory
void write_memory(uint32_t addr, uint8_t* data, size_t size) {
    uint8_t* memory = (uint8_t*)(uintptr_t)addr; // Use uintptr_t for correct casting
    for (size_t i = 0; i < size; ++i) {
        memory[i] = data[i];
    }
}

// Quantization function
int8_t quantize(int32_t value, int scale) {
    return (int8_t)((value + (scale >> 1)) / scale); // Rounding with scale factor
}

// Convolution function
void conv2d(uint32_t input_addr, uint32_t weight_addr, uint32_t scale_addr, uint32_t output_addr,
            int input_channels, int output_channels, int kernel_size, int input_size, int output_size) {
    uint8_t* input = read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int8_t scale = *read_memory(scale_addr);
    uint8_t* output = (uint8_t*)(uintptr_t)output_addr; // Updated casting

    printf("Running Conv2D: input_addr=%x, weight_addr=%x, scale_addr=%x, output_addr=%x\n",
           input_addr, weight_addr, scale_addr, output_addr);

    for (int oc = 0; oc < output_channels; ++oc) {
        for (int oy = 0; oy < output_size; ++oy) {
            for (int ox = 0; ox < output_size; ++ox) {
                int32_t sum = 0;
                for (int ic = 0; ic < input_channels; ++ic) {
                    for (int ky = 0; ky < kernel_size; ++ky) {
                        for (int kx = 0; kx < kernel_size; ++kx) {
                            int iy = oy + ky;
                            int ix = ox + kx;
                            int input_idx = ((ic * input_size + iy) * input_size) + ix;
                            int weight_idx = (((oc * input_channels + ic) * kernel_size + ky) * kernel_size) + kx;
                            sum += input[input_idx] * weights[weight_idx];
                        }
                    }
                }
                int output_idx = (oc * output_size + oy) * output_size + ox;
                output[output_idx] = quantize(sum, scale);
                // printf("%d\n", output[output_idx]);
            }
        }
    }
}

// MaxPooling function
void maxpool2d(uint32_t input_addr, uint32_t output_addr, int channels, int input_size, int output_size) {
    uint8_t* input = read_memory(input_addr);
    uint8_t* output = (uint8_t*)(uintptr_t)output_addr; // Updated casting

    printf("Running MaxPool2D: input_addr=%x, output_addr=%x\n", input_addr, output_addr);

    for (int c = 0; c < channels; ++c) {
        for (int oy = 0; oy < output_size; ++oy) {
            for (int ox = 0; ox < output_size; ++ox) {
                int max_val = 0;
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
}

// Fully connected layer
void fully_connected(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, uint32_t scale_addr,
                     uint32_t output_addr, int input_size, int output_size) {
    int8_t* input = (int8_t*)read_memory(input_addr);
    int8_t* weights = (int8_t*)read_memory(weight_addr);
    int16_t* bias = (int16_t*)read_memory(bias_addr);
    int8_t scale = *read_memory(scale_addr);
    uint8_t* output = (uint8_t*)(uintptr_t)output_addr; // Updated casting

    printf("Running Fully Connected: input_addr=%x, weight_addr=%x, bias_addr=%x, scale_addr=%x, output_addr=%x\n",
           input_addr, weight_addr, bias_addr, scale_addr, output_addr);

    for (int o = 0; o < output_size; ++o) {
        int32_t sum = bias[o];
        for (int i = 0; i < input_size; ++i) {
            sum += input[i] * weights[o * input_size + i];
        }
        output[o] = quantize(sum, scale);
    }
}

// Main function
int main() {
    printf("Starting inference...\n");

    // Conv1
    conv2d(ADDR_INPUT, ADDR_WCONV1, ADDR_SCONV1, ADDR_OUTCONV1, 3, 12, 5, 32, 28);
    // Pool1
    maxpool2d(ADDR_OUTCONV1, ADDR_OUTPOOL1, 12, 28, 14);
    // Conv2
    conv2d(ADDR_OUTPOOL1, ADDR_WCONV2, ADDR_SCONV2, ADDR_OUTCONV2, 12, 32, 3, 14, 12);
    // Pool2
    maxpool2d(ADDR_OUTCONV2, ADDR_OUTPOOL2, 32, 12, 6);
    // Fully connected layers
    fully_connected(ADDR_OUTPOOL2, ADDR_WFC1, 0, ADDR_SFC1, ADDR_OUTFC1, 32 * 6 * 6, 256);
    fully_connected(ADDR_OUTFC1, ADDR_WFC2, 0, ADDR_SFC2, ADDR_OUTFC2, 256, 64);
    fully_connected(ADDR_OUTFC2, ADDR_WFC3, ADDR_BFC3, ADDR_SFC3, ADDR_OUTFC3, 64, 10);

    printf("Inference completed.\n");
    return 0;
}
