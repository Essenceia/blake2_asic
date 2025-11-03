`timescale 1ns / 1ps

module top(
	input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
); 
	wire       ready_v;
	wire       hash_v;
	wire [7:0] hash;
	
	wire [5:0]  kk,nn;
	wire [63:0] ll; 
	
	wire data_v; 
	wire [7:0] data; 
	wire [5:0] data_idx; 
	wire block_first, block_last;
	wire [2:0] unused_io; 

	assign uio_oe = 8'b1000_1000;
	assign uio_out[6:4] = 3'd0;
	assign uio_out[2:0] = 3'd0;
	assign unused_io = { uio_in[7:6], uio_in[3]};

	io_intf m_io(
		.clk(clk),
		.nreset(rst_n),
		.en_i(ena),

		.valid_i(uio_in[0]),
		.cmd_i(uio_in[2:1]),
		.data_i(ui_in),

		.loopback_mode_i(uio_in[5:4]),

		.ready_v_o(uio_out[3]),
		.hash_v_o(uio_out[7]),
		.hash_o(uo_out),

		.ready_v_i(ready_v),	
		.hash_v_i(hash_v),
		.hash_i(hash),

		.kk_o(kk),
		.nn_o(nn),
		.ll_o(ll),

		.data_v_o(data_v),
		.data_o(data),
		.data_idx_o(data_idx),
		.block_first_o(block_first),
		.block_last_o(block_last)
	);
	
	blake2s_hash256 m_blake2(
		.clk(clk),
		.nreset(rst_n),

		.kk_i(kk),
		.nn_i(nn),
		.ll_i(ll),

		.block_first_i(block_first),
		.block_last_i(block_last),

		.data_v_i(data_v),
		.data_i(data),
		.data_idx_i(data_idx),

		.ready_v_o(ready_v),

		.h_v_o(hash_v),
		.h_o(hash)
	);
endmodule

