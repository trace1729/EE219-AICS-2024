; =======================================
; task1_2
; =======================================

lui     x5,    2148532224             ; Load base address of A into x10
lui     x6,    2150629376             ; Load base address of B into x11
lui     x7,    2152726528             ; Load base address of C into x12
lui     x8,    2154823680             ; Load base address of D into x13

addi x9, x0, 0 ; x9 -> i
addi x12, x0, 8;

outer_loop:

blt x9, x12, next1;
jal x0, end 

next1:

addi x10, x0, 0 ; x10 -> j

inner_loop:

blt x10, x12, next2;
addi x9, x9, 1
jal x0, outer_loop;

next2:

addi x11, x0, 0 ; cnt
addi x20, x0, 0 ; accmulator

dot_product:
blt x11, x12, next3 ; x11 -> z
jal x0, bias

next3:
addi x13, x0, 4
mul x14, x9, x12 ; 8 * i
add x14, x14, x11 ; 8 * i + z
mul x14, x14, x13; (8 * i + z) * 4
add x15, x14, x5; A[i][z]
lw  x16, 0(x15) ; x16 = A[i][z]

mul x14, x11, x12 ; 8 * z
add x14, x14, x10 ; 8 * z + j
mul x14, x14, x13; (8 * z + j) * 4
add x15, x14, x6;  B[i][z]
lw  x17, 0(x15) ; x17 = B[z][j]

mul x19, x16, x17
add x20, x20, x19
addi x11, x11, 1
jal x0, dot_product 

bias:
mul x14, x10, x12 ; 8 * i
add x14, x14, x10 ; 8 * i + j
mul x14, x14, x13; (8 * i + j) * 4
add x15, x14, x7;  C[i][j]
lw  x18, 0(x15) ; x18 = C[z][j]

add x20, x20, x18 ;

add x15, x14, x8;
sw  x20, 0(x15) ; D[i][j] = x20

addi x10, x10, 1
jal x0, inner_loop

end:
halt