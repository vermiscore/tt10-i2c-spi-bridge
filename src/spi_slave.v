`timescale 1ns/1ps
// SPI Slave Module
// Mode 0 (CPOL=0, CPHA=0)

module spi_slave (
    input  wire       clk,
    input  wire       rst_n,

    // SPIバス
    input  wire       sck,
    input  wire       mosi,
    output reg        miso,
    input  wire       cs_n,

    // 内部インターフェース
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg        busy
);

// 3段FF同期
reg [2:0] sck_sr, mosi_sr, cs_sr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sck_sr  <= 3'b000;
        mosi_sr <= 3'b000;
        cs_sr   <= 3'b111;
    end else begin
        sck_sr  <= {sck_sr[1:0],  sck};
        mosi_sr <= {mosi_sr[1:0], mosi};
        cs_sr   <= {cs_sr[1:0],   cs_n};
    end
end

wire sck_rise  = ( sck_sr[1] & ~sck_sr[2]);
wire sck_fall  = (~sck_sr[1] &  sck_sr[2]);
wire mosi_s    = mosi_sr[1];
wire cs_active = ~cs_sr[1];  // Low=active
wire cs_start  = ( cs_sr[2] & ~cs_sr[1]); // CS立下り

reg [7:0] shift_rx;
reg [7:0] shift_tx;
reg [2:0] bit_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_rx <= 0; shift_tx <= 0;
        rx_data  <= 0; rx_valid <= 0;
        tx_ready <= 0; busy     <= 0;
        miso     <= 0; bit_cnt  <= 0;
    end else begin
        rx_valid <= 0;
        tx_ready <= 0;

        // CS立下りで開始
        if (cs_start) begin
            busy      <= 1;
            bit_cnt   <= 0;
            shift_tx  <= tx_data;
            tx_ready  <= 1;
            miso      <= tx_data[7]; // MSB先出し
        end

        // CS非アクティブで終了
        if (!cs_active) begin
            busy <= 0;
            miso <= 0;
        end

        if (cs_active) begin
            // SCK立上り: MOSIサンプル
            if (sck_rise) begin
                shift_rx <= {shift_rx[6:0], mosi_s};
                if (bit_cnt == 7) begin
                    rx_data  <= {shift_rx[6:0], mosi_s};
                    rx_valid <= 1;
                    bit_cnt  <= 0;
                end else begin
                    bit_cnt <= bit_cnt + 1;
                end
            end

            // SCK立下り: MISOシフト
            if (sck_fall) begin
                shift_tx <= {shift_tx[6:0], 1'b0};
                miso     <= shift_tx[6];
            end
        end
    end
end

endmodule
