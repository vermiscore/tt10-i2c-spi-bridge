`timescale 1ns/1ps
// I2C Slave Module (Fixed v2)
// Address: 7'h42 (変更可能)

module i2c_slave #(
    parameter ADDR = 7'h42
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       scl,
    input  wire       sda_in,
    output wire       sda_out,
    output wire       sda_oe,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg        busy
);

// 3段FF同期
reg [2:0] scl_sr, sda_sr;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scl_sr <= 3'b111; sda_sr <= 3'b111;
    end else begin
        scl_sr <= {scl_sr[1:0], scl};
        sda_sr <= {sda_sr[1:0], sda_in};
    end
end

wire scl_s    = scl_sr[1];
wire sda_s    = sda_sr[1];
wire scl_rise = ( scl_sr[1] & ~scl_sr[2]);
wire scl_fall = (~scl_sr[1] &  scl_sr[2]);
// START: SCL=H中のSDA立下り
wire start_det = scl_sr[2] & scl_sr[1] & (sda_sr[2] & ~sda_sr[1]);
// STOP:  SCL=H中のSDA立上り
wire stop_det  = scl_sr[2] & scl_sr[1] & (~sda_sr[2] & sda_sr[1]);

localparam IDLE      = 3'd0;
localparam ADDR_RCV  = 3'd1;
localparam ADDR_ACK  = 3'd2;
localparam DATA_RCV  = 3'd3;
localparam DATA_ACK  = 3'd4;
localparam DATA_SND  = 3'd5;
localparam DATA_NACK = 3'd6;

reg [2:0] state;
reg [3:0] bit_cnt;
reg [7:0] shift_reg;
reg       rw_bit;
reg       sda_oen;
reg       addr_match;
reg       ack_phase; // ACK状態の内部フェーズ管理

assign sda_out = 1'b0;
 assign sda_oe  = sda_oen;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE; bit_cnt <= 0; shift_reg <= 0;
        rw_bit <= 0; rx_data <= 0; rx_valid <= 0;
        tx_ready <= 0; busy <= 0; sda_oen <= 0;
        addr_match <= 0; ack_phase <= 0;
    end else begin
        rx_valid <= 0;
        tx_ready <= 0;

        if (start_det) begin
            state <= ADDR_RCV; bit_cnt <= 0;
            busy <= 1; sda_oen <= 0; shift_reg <= 0; ack_phase <= 0;
        end else if (stop_det) begin
            state <= IDLE; busy <= 0; sda_oen <= 0;
        end else begin
            case (state)
                IDLE: begin sda_oen <= 0; busy <= 0; end

                // アドレス+R/W受信
                ADDR_RCV: begin
                    if (scl_rise) begin
                        shift_reg <= {shift_reg[6:0], sda_s};
                        if (bit_cnt == 7) begin
                            rw_bit     <= sda_s;
                            addr_match <= (shift_reg[6:0] == ADDR);
                            bit_cnt    <= 0;
                            state      <= ADDR_ACK;
                            ack_phase  <= 0;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                // アドレスACK: scl_fallでLow出力 → 次のscl_fallで解放
                ADDR_ACK: begin
                    if (scl_fall) begin
                        if (!ack_phase) begin
                            sda_oen   <= addr_match;
                            ack_phase <= 1;
                        end else begin
                            sda_oen   <= 0;
                            ack_phase <= 0;
                            if (!addr_match) begin
                                state <= IDLE;
                            end else if (!rw_bit) begin
                                state <= DATA_RCV; bit_cnt <= 0;
                            end else begin
                                shift_reg <= {tx_data[6:0], 1'b0};
                                tx_ready  <= 1;
                                sda_oen   <= ~tx_data[7];
                                state     <= DATA_SND; bit_cnt <= 1;
                            end
                        end
                    end
                end

                // データ受信
                DATA_RCV: begin
                    if (scl_rise) begin
                        shift_reg <= {shift_reg[6:0], sda_s};
                        if (bit_cnt == 7) begin
                            rx_data  <= {shift_reg[6:0], sda_s};
                            rx_valid <= 1;
                            bit_cnt  <= 0;
                            state    <= DATA_ACK;
                            ack_phase <= 0;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end

                // データACK
                DATA_ACK: begin
                    if (scl_fall) begin
                        if (!ack_phase) begin
                            sda_oen   <= 1;
                            ack_phase <= 1;
                        end else begin
                            sda_oen   <= 0;
                            ack_phase <= 0;
                            state     <= DATA_RCV; bit_cnt <= 0;
                        end
                    end
                end

                // データ送信: SCL立下りでビットセット
                DATA_SND: begin
                   if (scl_fall) begin
                      sda_oen   <= ~shift_reg[7];
                      shift_reg <= {shift_reg[6:0], 1'b0};
                      if (bit_cnt == 7) begin
                          bit_cnt <= 0; state <= DATA_NACK;
                      end else begin
                         bit_cnt <= bit_cnt + 1;
                        end
    end
end

                // NACK待ち
                DATA_NACK: begin
                    sda_oen <= 0;
                    if (scl_rise) begin
                        if (sda_s) begin
                            state <= IDLE; busy <= 0;
                        end else begin
                            shift_reg <= {tx_data[6:0], 1'b0};  // 1ビット先にシフト
                            tx_ready  <= 1;
                            sda_oen   <= ~tx_data[7];           // MSBを即座に出力
                            state     <= DATA_SND; bit_cnt <= 1; // bit_cntを1から開始
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
end

endmodule
