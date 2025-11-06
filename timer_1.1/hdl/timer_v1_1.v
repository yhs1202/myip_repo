
`timescale 1 ns / 1 ps

	module timer_v1_1 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
		output wire intr,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
	timer_v1_1_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) timer_v1_1_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		.timer_en(timer_en),
		.intr_en(intr_en),
		.psc_top(psc_top),
		.cnt_top(cnt_top),
		.cnt(cnt)
	);

	// Add user logic here
	timer u_timer (
		.clk(s00_axi_aclk),
		.resetn(s00_axi_aresetn),
		.timer_en(timer_en),
		.intr_en(intr_en),
		.psc_top(psc_top),
		.cnt_top(cnt_top),
		.cnt(cnt),
		.intr(intr)
	);

	// User logic ends

	endmodule


module timer (
	input clk,
	input resetn,	// active low reset
	input timer_en,
	input intr_en,
	input [31:0] psc_top, 	// prescaler top
	input [31:0] cnt_top, 	// counter top
	output [31:0] cnt, 	// current counter value
	output intr
);
	wire psc_tick;
	wire cnt_tick;

	assign intr = intr_en & cnt_tick;

	prescaler u_prescaler (
		.clk(clk),
		.resetn(resetn),
		.en(timer_en),
		.psc_top(psc_top),
		.psc_tick(psc_tick)
	);

	timer_counter u_timer_counter (
		.clk(clk),
		.resetn(resetn),
		.psc_tick(psc_tick),
		.cnt_top(cnt_top),
		.cnt_tick(cnt_tick),
		.cnt(cnt)
	);

endmodule



module prescaler (
	input clk,
	input resetn,
	input en,
	input [31:0] psc_top,
	output psc_tick
);
	reg [31:0] psc_cnt;

	always @(posedge clk) begin	// synchronous reset
		if (!resetn) begin
			psc_cnt <= 32'b0;
		end else if (en) begin
			if (psc_cnt == psc_top - 1) begin
				psc_cnt <= 32'b0;
			end else begin
				psc_cnt <= psc_cnt + 1;
			end
		end
	end

	assign psc_tick = (psc_cnt == psc_top);

endmodule


module timer_counter (
	input clk,
	input resetn,
	input psc_tick,
	input [31:0] cnt_top,
	output reg cnt_tick,
	output reg [31:0] cnt
);

	always @(posedge clk) begin	// synchronous reset
		if (!resetn) begin
			cnt <= 32'b0;
			cnt_tick <= 1'b0;
		end else if (psc_tick) begin
			if (cnt == cnt_top - 1) begin
				cnt <= 32'b0;
				cnt_tick <= 1'b1;
			end else begin
				cnt <= cnt + 1;
				cnt_tick <= 1'b0;
			end
		end
	end
endmodule
