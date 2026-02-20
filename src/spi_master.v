`timescale 1ns/1ps
module spi_master #(
    parameter CLK_DIV = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        busy,
    output reg        sck,
    output reg        mosi,
    input  wire       miso,
    output reg        cs_n
);

reg [1:0] clk_cnt;
reg       sck_en;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_cnt <= 0; sck_en <= 0;
    end else begin
        sck_en <= 0;
        if (busy) begin
            if (clk_cnt == CLK_DIV-1) begin
                clk_cnt <= 0; sck_en <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end else begin
            clk_cnt <= 0;
        end
    end
end

localparam IDLE     = 2'd0;
localparam TRANSFER = 2'd1;
localparam CS_HOLD  = 2'd2;

reg [1:0] state;
reg [7:0] shift_tx;
reg [7:0] shift_rx;
reg [3:0] edge_cnt;  // SCKエッジ数 0~15 (8bit=16エッジ)

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE; sck <= 0; mosi <= 0; cs_n <= 1;
        busy <= 0; tx_ready <= 0; rx_data <= 0; rx_valid <= 0;
        shift_tx <= 0; shift_rx <= 0; edge_cnt <= 0;
    end else begin
        tx_ready <= 0; rx_valid <= 0;

        case (state)
            IDLE: begin
                sck <= 0; cs_n <= 1; busy <= 0;
                if (tx_valid) begin
                    shift_tx <= tx_data;
                    tx_ready <= 1;
                    busy     <= 1;
                    cs_n     <= 0;
                    edge_cnt <= 0;
                    mosi     <= tx_data[7];  // MSBを先出し
                    state    <= TRANSFER;
                end
            end

            TRANSFER: begin
                if (sck_en) begin
                    if (!sck) begin
                        // SCK立上り: MISOサンプル
                        sck      <= 1;
                        shift_rx <= {shift_rx[6:0], miso};
                        edge_cnt <= edge_cnt + 1;
                        if (edge_cnt == 7) begin
                            rx_data  <= {shift_rx[6:0], miso};
                            rx_valid <= 1;
                            state    <= CS_HOLD;
                        end
                    end else begin
                        // SCK立下り: MOSIシフト
                        sck      <= 0;
                        shift_tx <= {shift_tx[6:0], 1'b0};
                        mosi     <= shift_tx[6];
                    end
                end
            end

            CS_HOLD: begin
                sck <= 0;
                if (sck_en) begin
                    cs_n  <= 1;
                    busy  <= 0;
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end
endmodule
