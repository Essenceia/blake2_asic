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

module blake2b_hash512(
	input clk,
	input nreset,
	input          valid_i,
	input [1023:0] data_i,
	output         hash_v_o,
	output [511:0] hash_o // Seed, output of the hast512
	);
	blake2 #( .NN(64), .NN_b(8'b0100_0000)) m_hash512(
		.clk(clk),
		.nreset(nreset),
		.valid_i(valid_i),
		.d_i(data_i),
		.valid_o(hash_v_o),
		.h_o(hash_o)
	);
endmodule

module blake2s_hash256(
	input          clk,
	input 	       nreset,

	input 	       valid_i,
	input  [511:0] data_i,
	output         hash_v_o,
	output [255:0] hash_o
	);
	blake2 #( .NN(32), .NN_b(8'b0010_0000)) m_hash256(
		.clk(clk),
		.nreset(nreset),
		.valid_i(valid_i),
		.d_i(data_i),
		.valid_o(hash_v_o),
		.h_o(hash_o)
	);
endmodule
