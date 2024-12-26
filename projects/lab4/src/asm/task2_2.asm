; =======================================
; task2_2
; =======================================

; load memory address

# Initialize Base Addresses
lui     x1,    2149580800             ; Base address of A.T
lui     x2,    2151677952             ; Base address of B.T
lui     x3,    2153775104             ; Base address of C.T
lui     x4,    2155872256             ; Base address of D.T

lui     x5,    2148532224             ; Base address of A
lui     x6,    2150629376             ; Base address of B
lui     x7,    2152726528             ; Base address of C
lui     x8,    2154823680             ; Base address of D

addi    x17, x8, 0 ; x17 walks through D
addi    x18, x7, 0 ; x18 walks through C
addi    x9,    x0,     0              ; Row counter (i = 0)
addi    x12,   x0,     8              ; Limit (8 rows/columns)
addi    x22,   x0,     4

outer_loop:
blt     x9,    x12,   next1           ; If i < 8, process row
jal     x0,    end                    ; Else, exit program

next1:
addi    x10,   x0,     0              ; Column counter (j = 0)
addi    x20,   x0,     0              ; Reset accumulator

inner_loop:
blt     x10,   x12,   dot_product           ; If j < 8, process column
addi    x9,    x9,     1              ; Increment row counter
jal     x0,    outer_loop             ; Go to next row

dot_product:
vle32.v vx0, x5, 1; load A
vle32.v vx1, x2, 1; load B.T
vmul.vv vx2, vx1, vx0, 1; 
vse32.v vx2, x3, 1; save register to not-used address 

addi x13, x0, 0; x13 as counter
addi x14, x3, 0; x14 as memory index
addi x15, x0, 0; x15 as accumulator

accmulate:
blt x13, x12,  next2 ;
jal x0, save; 

next2:
lw x16, 0(x14) ;
add x15, x15, x16 ;
addi x13, x13, 1;
addi x14 x3, 4;
jal x0, accmulate ;

save:
lw x25, 0(x18) ; C
add x26, x25, x15; D = A * B + C
sw x26, 0(17);
addi x17, x17, 4;

addi    x10,   x10,   1               ; Increment column counter
jal     x0,    inner_loop             ; Repeat inner loop

end:
halt                                   ; End program




