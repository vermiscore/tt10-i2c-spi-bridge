`timescale 1ns/1ps
module fifo_buffer #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] wr_data,
    input  wire             wr_en,
    output wire             full,
    output wire [WIDTH-1:0] rd_data,
    input  wire             rd_en,
    output wire             empty,
    output wire [4:0]       count
);

localparam ADDR_W = 4;

reg [WIDTH-1:0] mem [0:DEPTH-1];
reg [ADDR_W:0]  wr_ptr, rd_ptr;

assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) &&
               (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
assign empty = (wr_ptr == rd_ptr);
assign count = wr_ptr - rd_ptr;

// FWFT: rd_dataは常にrdポインタのデータを出力
assign rd_data = mem[rd_ptr[ADDR_W-1:0]];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
    end else begin
        if (wr_en && !full)
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
        if (wr_en && !full)
            wr_ptr <= wr_ptr + 1;
        if (rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end
end
endmodule
