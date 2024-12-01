`timescale 1ns / 1ps

module systolic_array#(
    parameter M           = 5,  // Number of rows in X
    parameter N           = 3,  // Number of columns in X / rows in W
    parameter K           = 4,  // Number of columns in W
    parameter DATA_WIDTH  = 32
) (
    input clk,
    input rst_n,
    input [DATA_WIDTH*M-1:0] X,          // Input matrix X (one column per cycle)
    input [DATA_WIDTH*K-1:0] W,          // Input matrix W (one row per cycle)
    output reg [DATA_WIDTH*M*K-1:0] Y,   // Output matrix Y
    output reg done
);

    // Internal signals
    wire [DATA_WIDTH-1:0] x_in[M-1:0][K-1:0]; // Input X flow in rows
    wire [DATA_WIDTH-1:0] w_in[M-1:0][K-1:0]; // Input W flow in columns
    wire [DATA_WIDTH-1:0] y_out[M-1:0][K-1:0]; // Outputs from PEs

    // Array of PEs
    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : row_loop
            for (j = 0; j < K; j = j + 1) begin : col_loop
                pe #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) pe (
                    .clk(clk),
                    .rst(rst_n),
                    .x_in(j == 0 ? X[DATA_WIDTH*(i+1)-1 -: DATA_WIDTH] : x_in[i][j-1]), // Input from left or X
                    .w_in(i == 0 ? W[DATA_WIDTH*(j+1)-1 -: DATA_WIDTH] : w_in[i-1][j]), // Input from top or W
                    .x_out(x_in[i][j]),  // Propagate X to the next PE in the row
                    .w_out(w_in[i][j]),  // Propagate W to the next PE in the column
                    .y_out(y_out[i][j])  // Output of the PE
                );
            end
        end
    endgenerate

    // Collect outputs
    integer m, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Y <= 0;
            done <= 0;
        end else begin
            // Pack PE outputs into Y
            for (m = 0; m < M; m = m + 1) begin
                for (k = 0; k < K; k = k + 1) begin
                    Y[DATA_WIDTH*(m*K + k + 1)-1 -: DATA_WIDTH] <= y_out[m][k];
                end
            end

            // Set done signal (simplified, in practice add control logic for completion)
            done <= 1;
        end
    end

endmodule
