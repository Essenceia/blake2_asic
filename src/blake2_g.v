`timescale 1ns / 1ps

module right_rot #(
	parameter ROT_I=32,
	parameter W=64
	)
	(
	input wire  [W-1:0] data_i,
	output wire [W-1:0] data_o
	);
	assign data_o[W-1:0] = { data_i[ROT_I-1:0], data_i[W-1:ROT_I]};
endmodule

module adder_3way #(
	parameter W=64
	)
	(
	input wire [W-1:0] x0_i,
	input wire [W-1:0] x1_i,
	input wire [W-1:0] x2_i,
	
	output wire [W-1:0] y_o
	);
	wire         carry;
	wire         unused_carry;
	wire [W-1:0] tmp;
	
	assign { carry , tmp } = x0_i + x1_i;
	assign { unused_carry, y_o } = x2_i + { carry , tmp };
endmodule

//     	FUNCTION G( v[0..15], a, b, c, d, x, y )
//      |
//      |   v[a] := (v[a] + v[b] + x) mod 2**w
//      |   v[d] := (v[d] ^ v[a]) >>> R1
//      |   v[c] := (v[c] + v[d])     mod 2**w
//      |   v[b] := (v[b] ^ v[c]) >>> R2
//      |   v[a] := (v[a] + v[b] + y) mod 2**w
//      |   v[d] := (v[d] ^ v[a]) >>> R3
//      |   v[c] := (v[c] + v[d])     mod 2**w
//      |   v[b] := (v[b] ^ v[c]) >>> R4
//      |
//      |   RETURN v[0..15]
//      |
//      END FUNCTION.
module G #(
	parameter W=32,
	parameter R1=16,
	parameter R2=12,
	parameter R3=8,
	parameter R4=7
	)(
	input wire clk,

	input wire [W-1:0]  a_i,
	input wire [W-1:0]  b_i,
	input wire [W-1:0]  c_i,
	input wire [W-1:0]  d_i,
	input wire [W-1:0]  x_i,
	input wire [W-1:0]  y_i,

	output wire [W-1:0] a_o,
	output wire [W-1:0] b_o,
	output wire [W-1:0] c_o,
	output wire [W-1:0] d_o
	);
	wire [W-1:0] a0;
	wire [W-1:0] b0;
	wire [W-1:0] c0;
	wire [W-1:0] d0;
	wire unused_carry, unused_carry1;

	reg [W-1:0] a_q;
	reg [W-1:0] b_q;
	reg [W-1:0] c_q;
	reg [W-1:0] d_q;
	reg [W-1:0] y_q;

	// v[a] := (v[a] + v[b] + y) mod 2**w
	adder_3way #(.W(W)) m_add_0(
		.x0_i(a_i),
		.x1_i(b_i),
		.x2_i(x_i),
		.y_o(a0)
	);

	always @(posedge clk) begin
		a_q <= a0;
		b_q <= b_i;
		c_q <= c_i;
		d_q <= d_i; 
		y_q <= y_i; 
	end

	// v[d] := (v[d] ^ v[a]) >>> R1
	right_rot #(R1 , W) m_rot_0
	(
		.data_i((d_q ^ a_q)),
		.data_o(d0)
	);
	// v[c] := (v[c] + v[d])     mod 2**w
	assign {unused_carry, c0} = c_q + d0;
	
	// v[b] := (v[b] ^ v[c]) >>> R2
	right_rot #(R2 , W) m_rot_1
	(
		.data_i((b_q ^ c0)),
		.data_o(b0)
	);
	// v[a] := (v[a] + v[b] + y) mod 2**w
	adder_3way #(.W(W)) m_add_1
	(
		.x0_i(a_q),
		.x1_i(b0),
		.x2_i(y_q),
		.y_o(a_o)
	);
	// v[d] := (v[d] ^ v[a]) >>> R3
	right_rot #(R3 , W) m_rot_2
	(
		.data_i((d0 ^ a_o)),
		.data_o(d_o)
	);

	// v[c] := (v[c] + v[d])     mod 2**w
	assign {unused_carry1, c_o} = c0 + d_o;

	// v[b] := (v[b] ^ v[c]) >>> R4
	right_rot #(R4 , W) m_rot_3
	(
		.data_i((b0 ^ c_o)),
		.data_o(b_o)
	);

endmodule 
