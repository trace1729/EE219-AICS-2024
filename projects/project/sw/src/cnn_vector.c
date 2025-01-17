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
