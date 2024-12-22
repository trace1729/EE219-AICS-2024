; =======================================
; task1_2
; =======================================

lui     x10,    2148532224             ; Load base address of A into x10
lui     x11,    2150629376             ; Load base address of B into x11
lui     x12,    2152726528             ; Load base address of C into x12
lui     x13,    2154823680             ; Load base address of D into x13

addi    x14,    x0,     8           ; Outer loop counter (rows of A)
addi    x15,    x0,     8           ; Inner loop counter (columns of B)
addi    x16,    x0,     4           ; Element size (4 bytes)

outer_loop:
slti    x17,    x14,    1           ; Check if outer loop counter is 0
blt     x17,    x0,     end         ; Exit if all rows processed
addi    x18,    x0,     8           ; Reset inner loop counter
addi    x19,    x0,     0           ; Reset accumulator (dot product)

inner_loop:
slti    x20,    x18,    1           ; Check if inner loop counter is 0
blt     x20,    x0,     store_result ; Exit if all columns processed
addi    x21,    x0,     8           ; Reset element counter
addi    x22,    x0,     0           ; Reset partial accumulator

dot_product:
slti    x23,    x21,    1           ; Check if dot product loop counter is 0
blt     x23,    x0,     accumulate  ; Exit if dot product is done
lw      x24,    0(x10)              ; Load element from A
lw      x25,    0(x11)              ; Load element from B
mul     x26,    x24,    x25         ; Multiply A[row][col] * B[row][col]
add     x22,    x22,    x26         ; Accumulate partial sum
addi    x10,    x10,    4           ; Move to next element in A
addi    x11,    x11,    32          ; Move to next row in B
addi    x21,    x21,    -1          ; Decrement element counter
jal     x0,     dot_product         ; Repeat for next element

accumulate:
lw      x27,    0(x12)              ; Load bias from C
add     x22,    x22,    x27         ; Add bias to the accumulator
sw      x22,    0(x13)              ; Store result into D
addi    x13,    x13,    4           ; Increment D pointer
addi    x18,    x18,    -1          ; Decrement inner loop counter
jal     x0,     inner_loop          ; Repeat for next column

store_result:
addi    x10,    x10,    32          ; Move to the next row of A
addi    x12,    x12,    32          ; Move to the next row of C
addi    x14,    x14,    -1          ; Decrement outer loop counter
jal     x0,     outer_loop          ; Repeat for next row

end:
halt                                ; Terminate execution