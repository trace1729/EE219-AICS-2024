#include "trap.h"
#include "model.h"

void conv2d(uint32_t input_addr, uint32_t weight_addr, uint32_t scale_addr,
            uint32_t output_addr, uint8_t input_channels, uint8_t output_channels,
            uint8_t kernel_size, uint8_t input_size, uint8_t output_size) {
    int null;

    // Pack parameters into two 32-bit words
    uint32_t packed1 = (input_channels & 0xFF) | 
                       ((output_channels & 0xFF) << 8) | 
                       ((kernel_size & 0xFF) << 16) | 
                       ((input_size & 0xFF) << 24);

    uint32_t packed2 = (output_size & 0xFF) |
                       ((input_addr & 0xFFFF) << 8) | 
                       ((weight_addr & 0xFFFF) << 24);

    // Execute custom instruction
    __asm__ __volatile__(
        "lw a0, 0(%[scale_addr])\n"  // Load scaling factor into a0
        "lw a1, 0(%[output_addr])\n" // Load output address into a1
        // Custom instruction with packed parameters
        ".insn r 0x77, 0, 0, %[null], %[packed1], %[packed2]"
        : [null] "=r"(null)
        : [packed1] "r"(packed1), [packed2] "r"(packed2),
          [scale_addr] "r"(scale_addr), [output_addr] "r"(output_addr)
        : "a0", "a1");
}

void maxpool2d(uint32_t input_addr, uint32_t output_addr, uint8_t channels, 
               uint8_t input_size, uint8_t output_size) {
    int null;

    // Pack parameters into a 32-bit word
    uint32_t packed = (channels & 0xFF) | 
                      ((input_size & 0xFF) << 8) | 
                      ((output_size & 0xFF) << 16) | 
                      ((input_addr & 0xFFFF) << 24);

    // Execute custom instruction
    __asm__ __volatile__(
        "lw a0, 0(%[output_addr])\n" // Load output address into a0
        // Custom instruction with packed parameters
        ".insn r 0x77, 1, 0, %[null], %[packed], a0"
        : [null] "=r"(null)
        : [packed] "r"(packed), [output_addr] "r"(output_addr)
        : "a0");
}


void fully_connected(uint32_t input_addr, uint32_t weight_addr, uint32_t bias_addr, 
                     uint32_t scale_addr, uint32_t output_addr, uint16_t input_size, 
                     uint16_t output_size) {
    int null;

    // Pack parameters into two 32-bit words
    uint32_t packed1 = (input_size & 0xFFFF) | ((output_size & 0xFFFF) << 16);
    uint32_t packed2 = (input_addr & 0xFFFF) | 
                       ((weight_addr & 0xFFFF) << 16) | 
                       ((bias_addr & 0xFFFF) << 24);

    // Execute custom instruction
    __asm__ __volatile__(
        "lw a0, 0(%[scale_addr])\n"  // Load scaling factor into a0
        "lw a1, 0(%[output_addr])\n" // Load output address into a1
        // Custom instruction with packed parameters
        ".insn r 0x77, 2, 0, %[null], %[packed1], %[packed2]"
        : [null] "=r"(null)
        : [packed1] "r"(packed1), [packed2] "r"(packed2),
          [scale_addr] "r"(scale_addr), [output_addr] "r"(output_addr)
        : "a0", "a1");
}


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