`default_nettype none

module serdes (
	input wire clk, 
	
	input wire      data_v_i,
	input wire [7:0] data_i,

	output wire [511:0] data_o
	);

	
	reg [511:0] data_q;

	always @(posedge clk)
		if (data_v_i) data_q <= {data_q[504:0], data_i};

	assign data_o = data_q;
endmodule

module top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

	wire [511:0] data;
    wire [7:0] _unused_ioin = uio_in;

	wire hash_v;
	wire [255:0] hash;

	serdes m_serdes (
		.clk(clk),
		.data_i(ui_in),
		.data_v_i(ena),
		.data_o(data)
	); 

	blake2s_hash256 m_blake2(
		.clk(clk),
		.nreset(rst_n), 
		.valid_i(ena),
		.data_i(data),
	
		.hash_v_o(hash_v),
		.hash_o(hash)
	);
	assign uo_out = hash[255:247]; 
	assign uio_out = {'0, hash_v};
	assign uio_oe = '0;


endmodule
