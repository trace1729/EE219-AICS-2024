`timescale 1ns / 1ps

module systolic #(
    parameter int M = 12,
    parameter int N = 6,
    parameter int K = 8,
    parameter int ARR_SIZE = 4,
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH = 32
)(
    input clk,
    input rst,
    input enable_row_count_A,
    input [DATA_WIDTH*ARR_SIZE-1:0] A,
    input [DATA_WIDTH*ARR_SIZE-1:0] B,
    output [ACC_WIDTH*ARR_SIZE*ARR_SIZE-1:0] D,
    output [ARR_SIZE*ARR_SIZE-1:0] valid_D,
    output [31:0] pixel_cntr_A,
    output [31:0] slice_cntr_A,
    output [31:0] pixel_cntr_B,
    output [31:0] slice_cntr_B
);

wire [DATA_WIDTH*ARR_SIZE*(ARR_SIZE+1)-1:0] temp_a;
wire [DATA_WIDTH*ARR_SIZE*(ARR_SIZE+1)-1:0] temp_b;

reg [ARR_SIZE*ARR_SIZE*N-1:0] init_pe = 0;

reg [31:0] pixel_cntr_A_reg = 0;
reg [31:0] slice_cntr_A_reg = 0;
reg [31:0] pixel_cntr_B_reg = 0;
reg [31:0] slice_cntr_B_reg = 0;

assign temp_a [DATA_WIDTH*ARR_SIZE*(1)-1:DATA_WIDTH*ARR_SIZE*(1-1)] = A;
assign temp_b [DATA_WIDTH*ARR_SIZE*(1)-1:DATA_WIDTH*ARR_SIZE*(1-1)] = B;

assign pixel_cntr_A = pixel_cntr_A_reg;
assign pixel_cntr_B = pixel_cntr_B_reg;
assign slice_cntr_A = slice_cntr_A_reg;
assign slice_cntr_B = slice_cntr_B_reg;

integer row = 0;
integer col = 0;
integer col_b = 0;
integer n = 0;
integer jishu = 0;

always @(posedge clk, posedge rst) begin
   if (!rst) begin
     if (K/ARR_SIZE > 3) begin
       n = K/ARR_SIZE;
     end else begin
       n = 3;
     end
     if (col < (M/ARR_SIZE)) begin
          if (row < N+4) begin
            pixel_cntr_A_reg <= row;
            slice_cntr_A_reg <= col;
            pixel_cntr_B_reg <= row;
            slice_cntr_B_reg <= col_b;
            row = row + 1;
            if (row == (N+1)) begin
              row = 0;
              col_b = col_b + 1;
            end
          end
          if (col >= (M/ARR_SIZE)) begin
            col = 0;
          end
          if (col_b >= (n)) begin
            col_b = 0;
            col = col + 1;
          end
        end
   end
end

always @(posedge clk, posedge rst) begin
    if (!rst) begin
        if (jishu == 0) begin
          init_pe[jishu] <= 1;
        end else if (jishu > 0) begin
          init_pe[jishu] <= 1;
          init_pe[jishu-1] <= 0; 
          if (jishu == (N)) begin
            jishu = -1;
          end
        end
        jishu = jishu + 1;
    end
end

// Initialize PE structure
genvar i;
generate for (i = 0; i < ARR_SIZE; i = i + 1) begin : gen_PE_column
    genvar j;
    for (j = 0; j < ARR_SIZE; j = j + 1) begin : gen_PE_row
        pe #(
            .N(N),
            .DATA_WIDTH(DATA_WIDTH),
            .ACC_WIDTH(ACC_WIDTH)
        ) pe_n (
            .clk(clk),
            .rst(rst),
            .init(init_pe[i+j:i+j]),
            .in_a(temp_a[(j*ARR_SIZE+i+1)*DATA_WIDTH-1:(j*ARR_SIZE+i)*DATA_WIDTH]),
            .in_b(temp_b[(i*ARR_SIZE+j+1)*DATA_WIDTH-1:(i*ARR_SIZE+j)*DATA_WIDTH]),
            .out_a(temp_a[((j+1)*ARR_SIZE+i+1)*DATA_WIDTH-1:((j+1)*ARR_SIZE+i)*DATA_WIDTH]),
            .out_b(temp_b[((i+1)*ARR_SIZE+j+1)*DATA_WIDTH-1:((i+1)*ARR_SIZE+j)*DATA_WIDTH]),
            .out_sum(D[(i*ARR_SIZE+j+1)*ACC_WIDTH-1:(i*ARR_SIZE+j)*ACC_WIDTH]),
            .valid_D(valid_D[j+i*(ARR_SIZE)])
        );
    end
end
endgenerate

endmodule
