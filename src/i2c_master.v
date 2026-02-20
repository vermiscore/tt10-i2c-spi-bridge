`timescale 1ns/1ps
module i2c_master #(
    parameter CLK_DIV = 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [6:0] addr,
    input  wire       rw,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_ready,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        busy,
    output reg        ack_err,
    output reg        scl,
    inout  wire       sda
);
reg [7:0] clk_cnt;
reg       half_tick;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin clk_cnt <= 0; half_tick <= 0;
    end else begin
        half_tick <= 0;
        if (busy) begin
            if (clk_cnt == CLK_DIV-1) begin clk_cnt <= 0; half_tick <= 1;
            end else clk_cnt <= clk_cnt + 1;
        end else clk_cnt <= 0;
    end
end
reg sda_oen;
assign sda = sda_oen ? 1'b0 : 1'bz;
reg [2:0] sda_sr;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) sda_sr <= 3'b111;
    else        sda_sr <= {sda_sr[1:0], sda};
end
wire sda_in = sda_sr[2];
localparam S_IDLE=0,S_START1=1,S_START2=2,S_START3=3,S_SEND=4;
localparam S_ACK_L=5,S_ACK_H=6,S_ACK_F=7,S_RECV=8;
localparam S_NACK_L=9,S_NACK_H=10,S_STOP1=11,S_STOP2=12,S_STOP3=13;
reg [3:0] state;
reg [7:0] shift_reg;
reg [2:0] bit_cnt;
reg       is_addr;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state<=S_IDLE; scl<=1; sda_oen<=0; busy<=0;
        tx_ready<=0; rx_data<=0; rx_valid<=0; ack_err<=0;
        shift_reg<=0; bit_cnt<=0; is_addr<=1;
    end else begin
        tx_ready<=0; rx_valid<=0;
        case (state)
            S_IDLE: begin
                scl<=1; sda_oen<=0; busy<=0;
                if (tx_valid) begin
                    busy<=1; ack_err<=0; is_addr<=1;
                    shift_reg<={addr,rw}; bit_cnt<=0;
                    state<=S_START1;
                end
            end
            S_START1: if(half_tick) begin scl<=1; sda_oen<=0; state<=S_START2; end
            S_START2: if(half_tick) begin sda_oen<=1; state<=S_START3; end
            S_START3: if(half_tick) begin scl<=0; bit_cnt<=7; state<=S_SEND; end
            S_SEND: begin
                if(half_tick) begin
                    if(scl==0) begin
                        sda_oen<=~shift_reg[7]; scl<=1;
                    end else begin
                        scl<=0;
                        if(bit_cnt==0) begin
                            state<=S_ACK_L;
                        end else begin
                            shift_reg<={shift_reg[6:0],1'b0};
                            bit_cnt<=bit_cnt-1;
                        end
                    end
                end
            end
            S_ACK_L: if(half_tick) begin sda_oen<=0; scl<=1; state<=S_ACK_H; end
            S_ACK_H: if(half_tick) begin
                if(sda_in) begin ack_err<=1; scl<=0; state<=S_STOP1;
                end else begin scl<=0; state<=S_ACK_F; end
            end
            S_ACK_F: if(half_tick) begin
                if(is_addr) begin
                    is_addr<=0;
                    if(!rw) begin
                        shift_reg<=tx_data; tx_ready<=1;
                        bit_cnt<=7; state<=S_SEND;
                    end else begin bit_cnt<=7; state<=S_RECV; end
                end else state<=S_STOP1;
            end
            S_RECV: begin
                if(half_tick) begin
                    if(scl==0) begin scl<=1;
                    end else begin
                        shift_reg<={shift_reg[6:0],sda_in}; scl<=0;
                        if(bit_cnt==0) begin
                            rx_data<={shift_reg[6:0],sda_in};
                            rx_valid<=1; state<=S_NACK_L;
                        end else bit_cnt<=bit_cnt-1;
                    end
                end
            end
            S_NACK_L: if(half_tick) begin sda_oen<=1; scl<=1; state<=S_NACK_H; end
            S_NACK_H: if(half_tick) begin scl<=0; sda_oen<=0; state<=S_STOP1; end
            S_STOP1: if(half_tick) begin sda_oen<=1; scl<=0; state<=S_STOP2; end
            S_STOP2: if(half_tick) begin scl<=1; state<=S_STOP3; end
            S_STOP3: if(half_tick) begin sda_oen<=0; state<=S_IDLE; busy<=0; end
            default: state<=S_IDLE;
        endcase
    end
end
endmodule
