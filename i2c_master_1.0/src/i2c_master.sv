// I2C Controller Module
// Author: Hoseung Yoon
// Description: This module implements an I2C Master controller that handles address, 
//              data input/output, and multi-byte transactions.

`timescale 1ns / 1ps

module i2c_master(
    // global signals
	input logic clk,
	input logic rst,

    // I2C transaction signals
	input logic [6:0] addr,
	input logic [7:0] tx_data,    // input data to write (master -> slave)
	input logic i2c_en,           // I2C enable signal
	input logic rw,               // 0: write, 1: read

    // for external AXI interface
    // output logic is_ack,    // for test
    // output logic is_nack,   // for test
    output logic [7:0] rx_data,   // Received output data during read (slave -> master)
    output logic ready,           // Master idle flag (ready for next transaction)

    // I2C bus (open-drain)
	inout wire sda,
	inout wire scl
	);

    // State enumeration
    typedef enum logic [3:0] {
        IDLE,           // Waiting for I2C enable
        START,          // Start condition (SDA low while SCL high)
        ADDRESS,        // Send 7-bit address + R/W bit
        READ_ADDR_ACK,  // after address byte, check ACK from slave
        WRITE_DATA,     // write byte to slave (MSB first)
        WRITE_ACK,      // after read data, send ACK/NACK
        READ_DATA,      // read byte from slave
        READ_ACK,      // after data write, check ACK from slave and decide next
        STOP
    } state_t;
	
	localparam DIVIDE_BY = 4;   // divider for I2C clock

    
    // Internal registers
	state_t state;
    
    logic [7:0] tx_buf;   // write data buffer
    logic [7:0] addr_buf; // address + R/W buffer
    logic [3:0] bit_counter;


    // Output assignments
    assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;
    // assign is_ack = (state == READ_ADDR_ACK || state == READ_ACK) && (sda == 1'b0);
    // assign is_nack = (state == READ_ADDR_ACK || state == READ_ACK) && (sda == 1'b1);


    // I2C clock generation
    reg [7:0] i2c_clk_cnt = 0;
    reg i2c_clk = 1;
    
    always_ff @(posedge clk) begin : I2C_CLK_GEN
        if (i2c_clk_cnt == (DIVIDE_BY/2) - 1) begin
        i2c_clk <= ~i2c_clk;
        i2c_clk_cnt <= 0;
        end else i2c_clk_cnt <= i2c_clk_cnt + 1;
    end
	

    // SCL Control (synchronized with i2c_clk if scl_enable)
	reg scl_enable = 0;
	assign scl = (scl_enable == 0 ) ? 1'b1 : i2c_clk;
	always @(negedge i2c_clk, posedge rst) begin
		if(rst == 1) begin
			scl_enable <= 0;
		end else begin
			if ((state == IDLE) || (state == START) || (state == STOP)) begin
				scl_enable <= 0;
			end else begin
				scl_enable <= 1;
			end
		end
	end


    // SDA Control (negedge i2c_clk: change SDA when SCL is low)
	reg sda_out;
	reg sda_out_en;
	assign sda = sda_out_en ? sda_out : 1'bz;

	always_ff @(negedge i2c_clk, posedge rst) begin : SDA_CONTROL
		if(rst) begin
			sda_out_en <= 1;
			sda_out <= 1;
		end else begin
			case(state)
				START: begin
					sda_out_en <= 1;
					sda_out <= 0;
				end
				
				ADDRESS: begin
					sda_out <= addr_buf[bit_counter]; // SLA+R/W MSB-first
				end
				
				READ_ADDR_ACK: begin
					sda_out_en <= 0;    // Slave drives ACK/NACK
				end
				
				WRITE_DATA: begin 
					sda_out_en <= 1;
					sda_out <= tx_buf[bit_counter]; // Data MSB-first
				end

                READ_ACK: begin
                    sda_out_en <= 0;    // Slave drives ACK/NACK
                end
				
				READ_DATA: begin
					sda_out_en <= 0;    // Slave drives data
                    rx_data[bit_counter] <= sda;   // Sample data bit, shift left
				end

				WRITE_ACK: begin
					sda_out_en <= 1;    // Only READ ACK(0)/NACK(1)
					sda_out <= 0;
				end
				
				STOP: begin
					sda_out_en <= 1;
					sda_out <= 1;
				end
			endcase
		end
	end

    // Main FSM
	always @(posedge i2c_clk, posedge rst) begin
		if(rst) begin
			state <= IDLE;
            {rx_data, tx_buf, addr_buf, bit_counter} <= 0;
		end else begin
			case(state)
				IDLE: begin
					if (i2c_en) begin
						state <= START;
						addr_buf <= {addr, rw};
						tx_buf <= tx_data;
					end
					else state <= IDLE;
				end

				START: begin
					bit_counter <= 7;
					state <= ADDRESS;
				end

				ADDRESS: begin
					if (bit_counter == 0) begin
						// bit_counter <= 7;
						state <= READ_ADDR_ACK;
					end else bit_counter <= bit_counter - 1;
				end

				READ_ADDR_ACK: begin
					if (sda == 0) begin // ACK received
						if(addr_buf[0] == 0) begin
                            bit_counter <= 7;
                            state <= WRITE_DATA; // WRITE or READ
                        end else begin 
                            bit_counter <= 8; // to omit addr_ack sda
                            state <= READ_DATA;
                        end
					end 
                    else begin
                        state <= STOP; // NACK -> STOP
					end
				end

				WRITE_DATA: begin
					if(bit_counter == 0) begin
						state <= READ_ACK;
					end else bit_counter <= bit_counter - 1;    // Send data bit on following negedge i2c_clk
				end
				
				READ_ACK: begin
					if ((sda == 0) && (i2c_en == 1)) begin
                        state <= IDLE; // ACK received and more data to write
                    end
					else begin
                        state <= STOP; // NACK -> STOP
                    end
				end

				READ_DATA: begin
					if (bit_counter == 0) state <= WRITE_ACK;
					else bit_counter <= bit_counter - 1;        // Sample data bit on following negedge i2c_clk
				end
				
				WRITE_ACK: begin
					state <= STOP;
				end

				STOP: begin
					state <= IDLE;
				end
			endcase
		end
	end

endmodule
