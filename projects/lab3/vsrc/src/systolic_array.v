
`timescale 1ns / 1ps

module systolic_array #(
    parameter M           = 5,  // Number of rows in the input matrix X
    parameter N           = 3,  // Number of columns in the weight matrix W (also the number of PEs in a row)
    parameter K           = 4,  // Number of columns in the input matrix X (also the number of PEs in a column)
    parameter DATA_WIDTH  = 32  // Data width
) (
    input wire clk,
    input wire rst_n,
    input wire [DATA_WIDTH*M-1:0] X,  // Input data matrix X
    input wire [DATA_WIDTH*K-1:0] W,  // Weight matrix W
    output reg [DATA_WIDTH*M*K-1:0] Y,  // Output result matrix Y
    output reg done  // Signal indicating the completion of the computation
);

assign done = 1;

endmodule
