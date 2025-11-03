`timescale 1ns / 1ps

// Blake2 wrapper for 512 and 256 hash

// Parametric implementation of Blake2 to implement b and s versions.
// Note : Doesn't support the use of a secret key.

// Configurations for b and s versions :
//
//                            | BLAKE2b          | BLAKE2s          |
//              --------------+------------------+------------------+
//               Bits in word | w = 64           | w = 32           |
//               Rounds in F  | r = 12           | r = 10           |
//               Block bytes  | bb = 128         | bb = 64          |
//               Hash bytes   | 1 <= nn <= 64    | 1 <= nn <= 32    |
//               Key bytes    | 0 <= kk <= 64    | 0 <= kk <= 32    |
//               Input bytes  | 0 <= ll < 2**128 | 0 <= ll < 2**64  |
//              --------------+------------------+------------------+
//               G Rotation   | (R1, R2, R3, R4) | (R1, R2, R3, R4) |
//                constants = | (32, 24, 16, 63) | (16, 12,  8,  7) |
//              --------------+------------------+------------------+
module blake2s_hash256(
	input wire         clk,
	input wire         nreset,

	input wire [5:0]   kk_i,
	input wire [5:0]   nn_i,
	input wire [63:0]  ll_i,

	input wire         block_first_i,               
	input wire         block_last_i,               
	
	input wire         data_v_i,
	input wire [5:0]   data_idx_i,	
	input wire [7:0]   data_i,

	output wire        ready_v_o,	
	output wire        h_v_o,
	output wire [7:0]  h_o
	);
	blake2 #( 
		.W(32),
		.R1(16),
		.R2(12),
		.R3(8),
		.R4(7),
		.R(4'd10)
		) m_hash256(
		.clk(clk),
		.nreset(nreset),

		.kk_i(kk_i),
		.nn_i(nn_i),
		.ll_i(ll_i),
		
		.block_first_i(block_first_i),
		.block_last_i(block_last_i),
		
		.data_v_i(data_v_i),
		.data_idx_i(data_idx_i),
		.data_i(data_i),
		
		.ready_v_o(ready_v_o),
		.h_v_o(h_v_o),
		.h_o(h_o)
	);
endmodule
