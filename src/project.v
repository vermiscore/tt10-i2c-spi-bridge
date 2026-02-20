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
    wire i2c_sda_s_out, i2c_sda_s_oe;
    wire i2c_sda_m_out, i2c_sda_m_oe;
    wire i2c_sda_s_wire = i2c_sda_s_oe ? i2c_sda_s_out : uio_in[0];
    wire i2c_sda_m_wire = i2c_sda_m_oe ? i2c_sda_m_out : uio_in[1];
    assign uio_out[0] = i2c_sda_s_out;
    assign uio_out[1] = i2c_sda_m_out;
    assign uio_out[7:2] = 6'b0;
    assign uio_oe[0] = i2c_sda_s_oe;
    assign uio_oe[1] = i2c_sda_m_oe;
    assign uio_oe[7:2] = 6'b0;
    top_bridge #(.I2C_ADDR(7'h42),.SPI_CLK_DIV(4),.I2C_CLK_DIV(125)) bridge (
        .clk(clk),.rst_n(rst_n),
        .i2c_sda_s(i2c_sda_s_wire),.i2c_scl_s(ui_in[0]),
        .i2c_scl_m(uo_out[0]),.i2c_sda_m(i2c_sda_m_wire),
        .spi_sck_m(uo_out[1]),.spi_mosi_m(uo_out[2]),
        .spi_miso_m(ui_in[5]),.spi_cs_n_m(uo_out[3]),
        .spi_sck_s(ui_in[2]),.spi_mosi_s(ui_in[3]),
        .spi_miso_s(uo_out[4]),.spi_cs_n_s(ui_in[4])
    );
    assign uo_out[7:5] = 3'b0;
endmodule
