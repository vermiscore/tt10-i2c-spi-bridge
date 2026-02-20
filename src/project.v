`default_nettype none
module tt_um_i2c_spi_bridge (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // ピン割り当て
  // ui_in: [0]=i2c_scl_s, [1]=i2c_sda_s_in, [2]=spi_sck_s, [3]=spi_mosi_s, [4]=spi_cs_n_s, [5]=spi_miso_m
  // uo_out: [0]=i2c_scl_m, [1]=spi_sck_m, [2]=spi_mosi_m, [3]=spi_cs_n_m, [4]=spi_miso_s
  // uio: [0]=i2c_sda_s(bidir), [1]=i2c_sda_m(bidir)

  wire i2c_scl_s   = ui_in[0];
  wire i2c_sda_s_i = uio_in[0];
  wire spi_sck_s   = ui_in[2];
  wire spi_mosi_s  = ui_in[3];
  wire spi_cs_n_s  = ui_in[4];
  wire spi_miso_m  = ui_in[5];

  wire i2c_scl_m;
  wire i2c_sda_m_o, i2c_sda_m_oe;
  wire i2c_sda_s_o, i2c_sda_s_oe;
  wire spi_sck_m, spi_mosi_m, spi_cs_n_m;
  wire spi_miso_s;

  top_bridge #(.I2C_ADDR(7'h42), .SPI_CLK_DIV(4)) u_bridge (
    .clk        (clk),
    .rst_n      (rst_n),
    .i2c_scl_s  (i2c_scl_s),
    .i2c_sda_s  (uio_in[0]),
    .i2c_scl_m  (i2c_scl_m),
    .i2c_sda_m  (uio_in[1]),
    .spi_sck_m  (spi_sck_m),
    .spi_mosi_m (spi_mosi_m),
    .spi_miso_m (spi_miso_m),
    .spi_cs_n_m (spi_cs_n_m),
    .spi_sck_s  (spi_sck_s),
    .spi_mosi_s (spi_mosi_s),
    .spi_miso_s (spi_miso_s),
    .spi_cs_n_s (spi_cs_n_s)
  );

  assign uo_out[0] = i2c_scl_m;
  assign uo_out[1] = spi_sck_m;
  assign uo_out[2] = spi_mosi_m;
  assign uo_out[3] = spi_cs_n_m;
  assign uo_out[4] = spi_miso_s;
  assign uo_out[7:5] = 3'b0;

  // uio[0] = i2c_sda_s (bidir), uio[1] = i2c_sda_m (bidir)
  assign uio_out[0] = 0;
  assign uio_out[1] = 0;
  assign uio_out[7:2] = 6'b0;
  assign uio_oe[1:0] = 2'b00; // 入力として使用
  assign uio_oe[7:2] = 6'b0;

  wire _unused = &{ena, 1'b0};
endmodule
