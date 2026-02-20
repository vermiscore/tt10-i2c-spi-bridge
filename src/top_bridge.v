`timescale 1ns/1ps
// I2C↔SPI ブリッジ トップモジュール
// 
// 動作:
//   I2Cマスター(外部) → このチップ → SPIスレーブ(外部センサー等)
//   SPIマスター(外部) → このチップ → I2Cスレーブ(外部センサー等)
//
// アドレスマップ (I2Cスレーブとして):
//   0x42: このブリッジのI2Cアドレス
//   受信1バイト目: コマンド (0x01=I2C→SPI転送, 0x02=SPI→I2C転送)
//   受信2バイト目以降: データ

module top_bridge #(
    parameter I2C_ADDR = 7'h42,
    parameter SPI_CLK_DIV = 4,
    parameter I2C_CLK_DIV = 125
)(
    input  wire clk,
    input  wire rst_n,

    // I2Cバス（スレーブとして）
    input  wire i2c_sda_s_in,
    output wire i2c_sda_s_out,
    output wire i2c_sda_s_oe,
    input  wire i2c_scl_s,

    // I2Cバス（マスターとして）
    output wire i2c_scl_m,
    input  wire i2c_sda_m_in,
    output wire i2c_sda_m_out,
    output wire i2c_sda_m_oe,

    // SPIバス（マスターとして）
    output wire spi_sck_m,
    output wire spi_mosi_m,
    input  wire spi_miso_m,
    output wire spi_cs_n_m,

    // SPIバス（スレーブとして）
    input  wire spi_sck_s,
    input  wire spi_mosi_s,
    output wire spi_miso_s,
    input  wire spi_cs_n_s
);

// -------------------------------------------------------
// I2Cスレーブ（外部I2Cマスターと通信）
// -------------------------------------------------------
wire [7:0] i2cs_rx_data;
wire       i2cs_rx_valid;
reg  [7:0] i2cs_tx_data;
reg        i2cs_tx_valid;
wire       i2cs_tx_ready;
wire       i2cs_busy;

i2c_slave #(.ADDR(I2C_ADDR)) u_i2c_slave (
    .clk      (clk),
    .rst_n    (rst_n),
    .scl      (i2c_scl_s),
    .sda_in  (i2c_sda_s_in),
        .sda_out (i2c_sda_s_out),
        .sda_oe  (i2c_sda_s_oe),
    .rx_data  (i2cs_rx_data),
    .rx_valid (i2cs_rx_valid),
    .tx_data  (i2cs_tx_data),
    .tx_valid (i2cs_tx_valid),
    .tx_ready (i2cs_tx_ready),
    .busy     (i2cs_busy)
);

// -------------------------------------------------------
// SPIマスター（外部SPIデバイスに送信）
// -------------------------------------------------------
reg  [7:0] spim_tx_data;
reg        spim_tx_valid;
wire       spim_tx_ready;
wire [7:0] spim_rx_data;
wire       spim_rx_valid;
wire       spim_busy;

spi_master #(.CLK_DIV(SPI_CLK_DIV)) u_spi_master (
    .clk      (clk),
    .rst_n    (rst_n),
    .tx_data  (spim_tx_data),
    .tx_valid (spim_tx_valid),
    .tx_ready (spim_tx_ready),
    .rx_data  (spim_rx_data),
    .rx_valid (spim_rx_valid),
    .busy     (spim_busy),
    .sck      (spi_sck_m),
    .mosi     (spi_mosi_m),
    .miso     (spi_miso_m),
    .cs_n     (spi_cs_n_m)
);

// -------------------------------------------------------
// SPIスレーブ（外部SPIマスターと通信）
// -------------------------------------------------------
wire [7:0] spis_rx_data;
wire       spis_rx_valid;
reg  [7:0] spis_tx_data;
reg        spis_tx_valid;
wire       spis_tx_ready;
wire       spis_busy;

spi_slave u_spi_slave (
    .clk      (clk),
    .rst_n    (rst_n),
    .sck      (spi_sck_s),
    .mosi     (spi_mosi_s),
    .miso     (spi_miso_s),
    .cs_n     (spi_cs_n_s),
    .rx_data  (spis_rx_data),
    .rx_valid (spis_rx_valid),
    .tx_data  (spis_tx_data),
    .tx_valid (spis_tx_valid),
    .tx_ready (spis_tx_ready),
    .busy     (spis_busy)
);

// -------------------------------------------------------
// I2Cマスター（外部I2Cスレーブデバイスに送信）
// -------------------------------------------------------
reg  [6:0] i2cm_addr;
reg        i2cm_rw;
reg  [7:0] i2cm_tx_data;
reg        i2cm_tx_valid;
wire       i2cm_tx_ready;
wire [7:0] i2cm_rx_data;
wire       i2cm_rx_valid;
wire       i2cm_busy;
wire       i2cm_ack_err;

i2c_master #(.CLK_DIV(I2C_CLK_DIV)) u_i2c_master (
    .clk      (clk),
    .rst_n    (rst_n),
    .addr     (i2cm_addr),
    .rw       (i2cm_rw),
    .tx_data  (i2cm_tx_data),
    .tx_valid (i2cm_tx_valid),
    .tx_ready (i2cm_tx_ready),
    .rx_data  (i2cm_rx_data),
    .rx_valid (i2cm_rx_valid),
    .busy     (i2cm_busy),
    .ack_err  (i2cm_ack_err),
    .scl      (i2c_scl_m),
    .sda_in  (i2c_sda_m_in),
        .sda_out (i2c_sda_m_out),
        .sda_oe  (i2c_sda_m_oe)
);

// -------------------------------------------------------
// FIFOバッファ（I2CS→SPIMブリッジ用）
// -------------------------------------------------------
wire [7:0] fifo_i2c_to_spi_data;
wire       fifo_i2c_to_spi_full;
wire       fifo_i2c_to_spi_empty;
reg        fifo_i2c_to_spi_rd;

fifo_buffer #(.WIDTH(8), .DEPTH(16)) u_fifo_i2c_to_spi (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_data (i2cs_rx_data),
    .wr_en   (i2cs_rx_valid),
    .full    (fifo_i2c_to_spi_full),
    .rd_data (fifo_i2c_to_spi_data),
    .rd_en   (fifo_i2c_to_spi_rd),
    .empty   (fifo_i2c_to_spi_empty),
    .count   ()
);

// -------------------------------------------------------
// FIFOバッファ（SPIS→I2CMブリッジ用）
// -------------------------------------------------------
wire [7:0] fifo_spi_to_i2c_data;
wire       fifo_spi_to_i2c_full;
wire       fifo_spi_to_i2c_empty;
reg        fifo_spi_to_i2c_rd;

fifo_buffer #(.WIDTH(8), .DEPTH(16)) u_fifo_spi_to_i2c (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_data (spis_rx_data),
    .wr_en   (spis_rx_valid),
    .full    (fifo_spi_to_i2c_full),
    .rd_data (fifo_spi_to_i2c_data),
    .rd_en   (fifo_spi_to_i2c_rd),
    .empty   (fifo_spi_to_i2c_empty),
    .count   ()
);

// -------------------------------------------------------
// ブリッジ制御ロジック
// I2CS→SPIM: I2Cで受信したデータをSPIマスターで転送
// SPIS→I2CM: SPIで受信したデータをI2Cマスターで転送
// -------------------------------------------------------

// I2CS → SPIM
localparam BS_IDLE    = 2'd0;
localparam BS_WAIT    = 2'd1;
localparam BS_SEND    = 2'd2;

reg [1:0] bridge_i2c_spi_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bridge_i2c_spi_state <= BS_IDLE;
        spim_tx_data  <= 0;
        spim_tx_valid <= 0;
        fifo_i2c_to_spi_rd <= 0;
    end else begin
        spim_tx_valid      <= 0;
        fifo_i2c_to_spi_rd <= 0;

        case (bridge_i2c_spi_state)
            BS_IDLE: begin
                if (!fifo_i2c_to_spi_empty && !spim_busy) begin
                    fifo_i2c_to_spi_rd   <= 1;
                    bridge_i2c_spi_state <= BS_WAIT;
                end
            end
            BS_WAIT: begin
                // FIFOのデータが確定するまで1クロック待つ
                bridge_i2c_spi_state <= BS_SEND;
            end
            BS_SEND: begin
                spim_tx_data         <= fifo_i2c_to_spi_data;
                spim_tx_valid        <= 1;
                bridge_i2c_spi_state <= BS_IDLE;
            end
            default: bridge_i2c_spi_state <= BS_IDLE;
        endcase
    end
end

// SPIS → I2CM
reg [1:0] bridge_spi_i2c_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bridge_spi_i2c_state <= BS_IDLE;
        i2cm_tx_data  <= 0;
        i2cm_tx_valid <= 0;
        i2cm_addr     <= 7'h00;
        i2cm_rw       <= 0;
        fifo_spi_to_i2c_rd <= 0;
    end else begin
        i2cm_tx_valid      <= 0;
        fifo_spi_to_i2c_rd <= 0;

        case (bridge_spi_i2c_state)
            BS_IDLE: begin
                if (!fifo_spi_to_i2c_empty && !i2cm_busy) begin
                    fifo_spi_to_i2c_rd   <= 1;
                    bridge_spi_i2c_state <= BS_WAIT;
                end
            end
            BS_WAIT: begin
                bridge_spi_i2c_state <= BS_SEND;
            end
            BS_SEND: begin
                i2cm_tx_data         <= fifo_spi_to_i2c_data;
                i2cm_tx_valid        <= 1;
                i2cm_addr            <= 7'h50; // デフォルト転送先アドレス
                i2cm_rw              <= 0;
                bridge_spi_i2c_state <= BS_IDLE;
            end
            default: bridge_spi_i2c_state <= BS_IDLE;
        endcase
    end
end

// I2CS読み取りデータをSPISの送信バッファにも反映
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i2cs_tx_data  <= 8'hFF;
        i2cs_tx_valid <= 1;
        spis_tx_data  <= 8'hFF;
        spis_tx_valid <= 1;
    end else begin
        // SPIMの受信データをI2CSの返答として使用
        if (spim_rx_valid) begin
            i2cs_tx_data  <= spim_rx_data;
            i2cs_tx_valid <= 1;
        end
        // I2CMの受信データをSPISの返答として使用
        if (i2cm_rx_valid) begin
            spis_tx_data  <= i2cm_rx_data;
            spis_tx_valid <= 1;
        end
    end
end

endmodule
