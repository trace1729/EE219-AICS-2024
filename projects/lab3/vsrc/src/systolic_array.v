`timescale 1ns / 1ps

`timescale 1ns / 1ps

module systolic_array#(
    parameter M           = 5,
    parameter N           = 3,
    parameter K           = 4,
    parameter DATA_WIDTH  = 32
) (
    input clk,
    input rst_n,
    input [DATA_WIDTH*M-1:0] X,
    input [DATA_WIDTH*K-1:0] W,
    output reg [DATA_WIDTH*M*K-1:0] Y,
    output done
);

endmodule