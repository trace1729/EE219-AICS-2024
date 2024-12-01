
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
// Internal signal to track the progress
reg [31:0] cnt ;

// Generate the PE array
genvar i, j;
generate
    for (i = 0; i < M; i = i + 1) begin : pe_row
        for (j = 0; j < K; j = j + 1) begin : pe_column
            // Instantiate the PE
            pe #(.DATA_WIDTH(DATA_WIDTH)) pe_inst (
                .clk(clk),
                .rst(~rst_n),  // Invert the reset signal as it is active low
                .x_in(X[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH]),
                .w_in(W[(j+1)*DATA_WIDTH-1:j*DATA_WIDTH]),
                .x_out(),
                .w_out(),
                .y_out(Y[(i*K+j+1)*DATA_WIDTH-1:(i*K+j)*DATA_WIDTH])
            );
        end
    end
endgenerate

always @(posedge clk) begin
    if (!rst_n) begin
        cnt <= 0;
        done <= 0;
    end else begin
        cnt <= cnt  + 1;
        if (cnt >= (M > K? M: K) + N - 1) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end
end

endmodule
