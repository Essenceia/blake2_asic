`timescale 1ns / 1ps
	 
// G Rotation | (R1, R2, R3, R4)
// constants  | (32, 24, 16, 63) 

module right_rot #(
	parameter ROT_I=32,
	parameter W=64
	)
	(
	input  [W-1:0] data_i,
	output [W-1:0] data_o
	);
	assign data_o[W-1:0] = { data_i[ROT_I-1:0], data_i[W-1:ROT_I]};
endmodule

module addder_3way #(
	parameter W=64
	)
	(
	input [W-1:0] x0_i,
	input [W-1:0] x1_i,
	input [W-1:0] x2_i,
	
	output [W-1:0] y_o
	);
	wire         carry;
	wire         unused_carry;
	wire [W-1:0] tmp;
	
	assign { carry , tmp } = x0_i + x1_i;
	assign { unused_carry, y_o } = x2_i + { carry , tmp };
endmodule


// Main blake2 module
// default parameter configuration is for blake2b
module blake2 #(	
	parameter NN     = 64, // output hash size in bytes, hash-512 : 64, hash-256 : 32 
	parameter NN_b   = 8'b0100_0000, // hash size in binary, hash-512 : 8'b0100_0000, hash-256 : 8'b0010_0000
	parameter NN_b_l = 8, // NN_b bit length
	parameter W      = 64, 
	parameter LL_b   = { {(W*2)-8{1'b0}}, 8'b10000000},
	parameter F_b    = 1'b1, // final block flag
	parameter R1     = 32, // rotation bits, used in G
	parameter R2     = 24,
	parameter R3     = 16,
	parameter R4     = 63,
	parameter R      = 4'd12 // 4'b1100 number of rounds in v srambling
	)
	(
	input               clk,
	input               nreset,
	
	input               valid_i,	
	input [(W*16)-1:0]  d_i,
	
	output              valid_o,
	output [(W*8) -1:0] h_o
	);
	 
	reg  [3:0] fsm_q;
	wire [3:0] fsm_next;
	wire       fsm_en;
	wire       v_en;
	wire       final_round;
	
	wire [W-1:0] db_h[7:0];

	wire [W-1:0] v_init[15:0];
	wire [W-1:0] v_init_2[15:0];
	wire [W-1:0] v_next[15:0];
	wire [W-1:0] v_current[15:0];
	reg  [W-1:0] v_q[15:0];
	wire [W-1:0] v_p0[15:0]; // part 0
	wire [W-1:0] v_p1[15:0]; // part 1
	wire [W-1:0] v_p2[15:0]; // part 2
	wire [W-1:0] v_p3[15:0]; // part 3
	wire [1:0]   unused_v_add_carry_p0[15:0]; // part 0
	wire [1:0]   unused_v_add_carry_p1[15:0]; // part 1
	wire [1:0]   unused_v_add_carry_p2[15:0]; // part 2
	wire [1:0]   unused_v_add_carry_p3[15:0]; // part 3
	
	reg  [W-1:0] m_q[15:0]; // stay the same for the entire periode 
	wire [W-1:0] m_current[15:0];
	wire [W-1:0] m_prime[15:0]; // m[s[i]]
		 
	wire [W-1:0] IV[0:7];
	wire [W-1:0] h_init[0:7];
	wire [63:0]  SIGMA[9:0];
	wire [3:0]   sigma_sel;
	wire [63:0]  sigma_row; // currently selected sigma row
	wire [3:0]   sigma_row_elems[15:0]; // currently selected sigma row
	
	assign SIGMA[0] = { 4'd15 , 4'd14, 4'd13, 4'd12, 4'd11, 4'd10, 4'd9,  4'd8,  4'd7,  4'd6,  4'd5,   4'd4,   4'd3,  4'd2,  4'd1,  4'd0 };
	assign SIGMA[1] = { 4'd3  , 4'd5,  4'd7,  4'd11, 4'd2,  4'd0,  4'd12, 4'd1,  4'd6,  4'd13, 4'd15,  4'd9,   4'd8,  4'd4,  4'd10, 4'd14};
	assign SIGMA[2] = { 4'd4  , 4'd9,  4'd1,  4'd7,  4'd6,  4'd3,  4'd14, 4'd10, 4'd13, 4'd15, 4'd2,   4'd5,   4'd0,  4'd12, 4'd8,  4'd11};
	assign SIGMA[3] = { 4'd8  , 4'd15, 4'd0,  4'd4,  4'd10, 4'd5,  4'd6,  4'd2,  4'd14, 4'd11, 4'd12,  4'd13,  4'd1,  4'd3,  4'd9,  4'd7 };
	assign SIGMA[4] = { 4'd13 , 4'd3,  4'd8,  4'd6,  4'd12, 4'd11, 4'd1,  4'd14, 4'd15, 4'd10, 4'd4,   4'd2,   4'd7,  4'd5,  4'd0,  4'd9 };
	assign SIGMA[5] = { 4'd9  , 4'd1,  4'd14, 4'd15, 4'd5,  4'd7,  4'd13, 4'd4,  4'd3,  4'd8,  4'd11,  4'd0,   4'd10, 4'd6,  4'd12, 4'd2 };
	assign SIGMA[6] = { 4'd11 , 4'd8,  4'd2,  4'd9,  4'd3,  4'd6,  4'd7,  4'd0,  4'd10, 4'd4,  4'd13,  4'd14,  4'd15, 4'd1,  4'd5,  4'd12};
	assign SIGMA[7] = { 4'd10 , 4'd2,  4'd6,  4'd8,  4'd4,  4'd15, 4'd0,  4'd5,  4'd9,  4'd3,  4'd1,   4'd12,  4'd14, 4'd7,  4'd11, 4'd13};
	assign SIGMA[8] = { 4'd5  , 4'd10, 4'd4,  4'd1,  4'd7,  4'd13, 4'd2,  4'd12, 4'd8,  4'd0,  4'd3,   4'd11,  4'd9,  4'd14, 4'd15, 4'd6 };
	assign SIGMA[9] = { 4'd0  , 4'd13, 4'd12, 4'd3,  4'd14, 4'd9,  4'd11, 4'd15, 4'd5,  4'd1,  4'd6,   4'd7,   4'd4,  4'd8,  4'd2,  4'd10};
	       				 
	assign IV[0] = 64'h6A09E667F3BCC908;
	assign IV[1] = 64'hBB67AE8584CAA73B;
	assign IV[2] = 64'h3C6EF372FE94F82B;
	assign IV[3] = 64'hA54FF53A5F1D36F1;
	assign IV[4] = 64'h510E527FADE682D1;
	assign IV[5] = 64'h9B05688C2B3E6C1F;
	assign IV[6] = 64'h1F83D9ABFB41BD6B;
	assign IV[7] = 64'h5BE0CD19137E2179;
	
	// Initialize h init
	genvar h_idx;
	generate
	       	// h[1..7] := IV[1..7] // Initialization Vector.
	        for(h_idx=1; h_idx<8; h_idx=h_idx+1) begin : loop_h_init
	       		assign h_init[h_idx] = IV[h_idx];
	       end
	endgenerate
	// Parameter block p[0]
	// h[0] := h[0] ^ 0x01010000 ^ (kk << 8) ^ nn
	assign h_init[0] = IV[0] ^ {{W-32{1'b0}},32'h01010000} ^ {{W-NN_b_l{1'b0}} , NN_b};
	
	
	// Initialize local work vector v[0..15]
	// v[0..7]  := h[0..7]              // First half from state.
	// v[8..15] := IV[0..7]            // Second half from IV.
	genvar v_init_i;
	generate
		for(v_init_i=0;v_init_i<8;v_init_i=v_init_i+1) begin : loop_v_init
			 assign v_init[v_init_i]   = h_init[v_init_i];
			 assign v_init[v_init_i+8] = IV[v_init_i];
			 assign db_h[v_init_i]     = h_init[v_init_i];
		end
	 endgenerate
//       |   v[12] := v[12] ^ (t mod 2**w)   // Low word of the offset.
//       |   v[13] := v[13] ^ (t >> w)       // High word.
//       |   IF f = TRUE THEN                // last block flag?
//       |   |   v[14] := v[14] ^ 0xFF..FF   // Invert all bits.
//       |   END IF.
	assign v_init_2[15] = v_init[15];
//	assign v_init_2[14] = v_init[14] ^ {W{F_b}};
	assign v_init_2[14] = v_init[14] ^ {W{1'b1}};
	assign v_init_2[13] = v_init[13] ^ LL_b[2*W-1:W];// High word of the offset
	assign v_init_2[12] = v_init[12] ^ LL_b[W-1:0]; // Low word of the offset
	genvar v_init_2_i;
	generate
		for(v_init_2_i=0;v_init_2_i<12; v_init_2_i=v_init_2_i+1) begin : loop_v_init_2_i
			assign v_init_2[v_init_2_i] = v_init[v_init_2_i];
		end
	endgenerate
	

        // do 12 rounds
	genvar v_idx;
	generate
		for(v_idx = 0; v_idx<16; v_idx=v_idx+1 ) begin : loop_v_idx
			assign v_current[v_idx] = valid_i ? v_init_2[v_idx] : v_q[v_idx];
				
			assign v_next[v_idx] = v_p3[v_idx];
			always @(posedge clk) 
			begin
				if ( v_en )
					v_q[v_idx] <= v_next[v_idx];
			end
		end
	endgenerate
	// TODO : modify list block flag
	//
	// modulo can only be done with a power of 2 on the right hand side
	// 10 : 01010, 11 : 01011, 12 : 01100
	//      00000,      00001       00010
	wire fsm_ge10;
	wire fsm_eq12;
	assign fsm_ge10 = fsm_q[3] & fsm_q[1];
	assign fsm_eq12 = fsm_q[3] & fsm_q[2];
	assign sigma_sel = fsm_ge10 ? { 3'b0 , fsm_q[0] }
						  : fsm_eq12 ? 4'b0010 : fsm_q;

	// select current sigma row
	// from rfc : "For BLAKE2b, the two extra permutations for rounds 
	// 10 and 11 are SIGMA[10..11] = SIGMA[0..1]" 
	assign sigma_row  = {64{ sigma_sel == 4'd0 }} & SIGMA[0]
			  | {64{ sigma_sel == 4'd1 }} & SIGMA[1]
			  | {64{ sigma_sel == 4'd2 }} & SIGMA[2]
			  | {64{ sigma_sel == 4'd3 }} & SIGMA[3]
			  | {64{ sigma_sel == 4'd4 }} & SIGMA[4]
			  | {64{ sigma_sel == 4'd5 }} & SIGMA[5]
			  | {64{ sigma_sel == 4'd6 }} & SIGMA[6]
			  | {64{ sigma_sel == 4'd7 }} & SIGMA[7]
			  | {64{ sigma_sel == 4'd8 }} & SIGMA[8]
			  | {64{ sigma_sel == 4'd9 }} & SIGMA[9];
	genvar j;
	generate
		for( j = 0; j < 16; j=j+1 ) begin : loop_sigma_elem
			assign sigma_row_elems[j] = sigma_row[j*4+3:j*4];
		end
	endgenerate
	
	genvar m_q_i;
	generate
		for(m_q_i=0; m_q_i<16; m_q_i=m_q_i+1 ) begin : loop_m_q_i
			// ff
			always @(posedge clk)
			begin
				if (valid_i)
					m_q[m_q_i] <= m_current[m_q_i];
			end
			// m_current ( stand in for next )
			assign m_current[m_q_i] = valid_i ? d_i[(W*m_q_i)+(W-1): W*m_q_i ] : m_q[m_q_i];
		end
	endgenerate
		
	// selecting m prime, re-ordered and indexed into by sigma_row_elems
	// this is the where this get's expensive in hw
	//
	// m_prime[i] = m[s[i]]
	genvar i;
	generate
		for ( i = 0; i < 16; i=i+1 ) begin : loop_m_prime_elem
			assign m_prime[i] = {64{ sigma_row_elems[i] == 4'd0  }} & m_current[0]
					  | {64{ sigma_row_elems[i] == 4'd1  }} & m_current[1]
					  | {64{ sigma_row_elems[i] == 4'd2  }} & m_current[2]
					  | {64{ sigma_row_elems[i] == 4'd3  }} & m_current[3]
					  | {64{ sigma_row_elems[i] == 4'd4  }} & m_current[4]
					  | {64{ sigma_row_elems[i] == 4'd5  }} & m_current[5]
					  | {64{ sigma_row_elems[i] == 4'd6  }} & m_current[6]
					  | {64{ sigma_row_elems[i] == 4'd7  }} & m_current[7]
					  | {64{ sigma_row_elems[i] == 4'd8  }} & m_current[8]
					  | {64{ sigma_row_elems[i] == 4'd9  }} & m_current[9]
					  | {64{ sigma_row_elems[i] == 4'd10 }} & m_current[10]
					  | {64{ sigma_row_elems[i] == 4'd11 }} & m_current[11]
					  | {64{ sigma_row_elems[i] == 4'd12 }} & m_current[12]
					  | {64{ sigma_row_elems[i] == 4'd13 }} & m_current[13]
					  | {64{ sigma_row_elems[i] == 4'd14 }} & m_current[14]
					  | {64{ sigma_row_elems[i] == 4'd15 }} & m_current[15]
					  ;
		end
	endgenerate
//      |   // Cryptographic mixing
//      |   FOR i = 0 TO r - 1 DO           // Ten or twelve rounds.
//      |   |
//      |   |   // Message word selection permutation for this round.
//      |   |   s[0..15] := SIGMA[i mod 10][0..15]
//      |   |
//      |   |   v := G( v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]] )
//      |   |   v := G( v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]] )
//      |   |   v := G( v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]] )
//      |   |   v := G( v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]] )
//      |   |
//      |   |   v := G( v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]] )
//      |   |   v := G( v, 1, 6, 11, 12, m[s[10]], m[s[11]] )
//      |   |   v := G( v, 2, 7,  8, 13, m[s[12]], m[s[13]] )
//      |   |   v := G( v, 3, 4,  9, 14, m[s[14]], m[s[15]] )
//      |   |
//      |   END FOR
// 
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

	genvar p0_idx;
// There is a constant gap between the values of a, b, c and d : 
//
//                   G( v, a, b,  c,  d,    x,     y)         p0_idx
//      |   |   v := G( v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]] ) 0
//      |   |   v := G( v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]] ) 1
//      |   |   v := G( v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]] ) 2
//      |   |   v := G( v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]] ) 3
	generate 
		for(p0_idx=0; p0_idx<4; p0_idx=p0_idx+1 ) begin : loop_g_v_part0
			localparam a = p0_idx;
			localparam b = p0_idx + 4;
			localparam c = p0_idx + 8;
			localparam d = p0_idx + 12;
			localparam x = p0_idx*2;
			localparam y = p0_idx*2+1;
			// Part 0
			// v[a] := (v[a] + v[b] + x) mod 2**w
			assign { unused_v_add_carry_p0[a], v_p0[a] }= v_current[a] + v_current[b] + m_prime[x];
			// v[d] := (v[d] ^ v[a]) >>> R1
			right_rot #(R1 , W) rot_p0_r1
			(
				.data_i((v_current[d] ^ v_p0[a])),
				.data_o(v_p0[d])
			);
			// v[c] := (v[c] + v[d])     mod 2**w
			assign { unused_v_add_carry_p0[c] , v_p0[c] } = v_current[c] + v_p0[d];
			// v[b] := (v[b] ^ v[c]) >>> R2
			right_rot #( R2, W) rot_p0_r2
			(
				.data_i((v_current[b] ^ v_p0[c])),
				.data_o(v_p0[b])
			);
			// Part 1
			// v[a] := (v[a] + v[b] + y) mod 2**w
			addder_3way add3_p0_2(
				.x0_i(v_p0[a]),
				.x1_i(v_p0[b]),
				.x2_i(m_prime[y]),
				.y_o(v_p1[a])
			);
	
			// v[d] := (v[d] ^ v[a]) >>> R3
			right_rot #(R3, W ) rot_p1_r3
			(
				.data_i((v_p0[d] ^ v_p1[a])),
				.data_o(v_p1[d])
			);
			// v[c] := (v[c] + v[d])     mod 2**w
			assign { unused_v_add_carry_p1[c], v_p1[c] } = v_p0[c] + v_p1[d];
			// v[b] := (v[b] ^ v[c]) >>> R4
			right_rot #( R4, W ) rot_p1_r4
			(
				.data_i((v_p0[b] ^ v_p1[c])),
				.data_o(v_p1[b])
			);
		end
	endgenerate
	genvar p2_idx;
	//          v, a, b, c,   d,     x   , y  
	//  v := G( v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]] )
	//  v := G( v, 1, 6, 11, 12, m[s[10]], m[s[11]] )
	//  v := G( v, 2, 7,  8, 13, m[s[12]], m[s[13]] )
	//  v := G( v, 3, 4,  9, 14, m[s[14]], m[s[15]] )
	generate 
		for(p2_idx=0; p2_idx<4; p2_idx=p2_idx+1) begin : loop_g_v_part2
			localparam a = p2_idx;
			localparam b = 4  + ((p2_idx + 1) % 4);//  5   6,  7,  4
			localparam c = 8  + ((p2_idx + 2) % 4);// 10, 11,  8,  9
			localparam d = 12 + ((p2_idx + 3) % 4);// 15, 12, 13, 14
			localparam x = (p2_idx*2) + 8; // 8, 10, 12, 14
			localparam y = (p2_idx*2) + 9; // 9, 11, 13, 15
			// Part 2
			// v[a] := (v[a] + v[b] + x) mod 2**w
			assign { unused_v_add_carry_p2[a], v_p2[a] } = v_p1[a] + v_p1[b] + m_prime[x];
			// v[d] := (v[d] ^ v[a]) >>> R1
			right_rot #(R1 , W) rot_p2_r1
			(
				.data_i((v_p1[d] ^ v_p2[a])),
				.data_o(v_p2[d])
			);
			// v[c] := (v[c] + v[d])     mod 2**w
			assign { unused_v_add_carry_p2[c], v_p2[c] } = v_p1[c] + v_p2[d];
			// v[b] := (v[b] ^ v[c]) >>> R2
			right_rot #( R2, W) rot_p2_r2
			(
				.data_i((v_p1[b] ^ v_p2[c])),
				.data_o(v_p2[b])
			);
			// Part 3
			// v[a] := (v[a] + v[b] + y) mod 2**w
			assign { unused_v_add_carry_p3[a], v_p3[a] } = v_p2[a] + v_p2[b] + m_prime[y];
			// v[d] := (v[d] ^ v[a]) >>> R3
			right_rot #(R3, W ) rot_p3_r3
			(
				.data_i((v_p2[d] ^ v_p3[a])),
				.data_o(v_p3[d])
			);
			// v[c] := (v[c] + v[d])     mod 2**w
			assign { unused_v_add_carry_p3[c], v_p3[c] } = v_p2[c] + v_p3[d];
			// v[b] := (v[b] ^ v[c]) >>> R4
			right_rot #( R4, W ) rot_p3_r4
			(
				.data_i((v_p2[b] ^ v_p3[c])),
				.data_o(v_p3[b])
			);
		end
	endgenerate
	
//      |   FOR i = 0 TO 7 DO               // XOR the two halves.
//      |   |   h[i] := h[i] ^ v[i] ^ v[i + 8]
//      |   END FOR.
//      |
//      |   RETURN h[0..7]                  // New state.

	// calculate output h_o value
	generate
		for(h_idx=0; h_idx<8; h_idx=h_idx+1 ) begin : loop_h_o
			assign h_o[(h_idx+1)*W-1:h_idx*W] = h_init[h_idx] ^ v_current[h_idx] ^ v_current[h_idx+8];
		end
	endgenerate
	
	// FSM : count to 12 
	// 0 1 2 3 4 5 6 7 8 9 10 11 12
	// v v v v v v v v v v v  v  h
	//                           fr
	always @(posedge clk)
	begin
		if(~nreset) begin
			fsm_q <= 4'b0000;
		end
		else if(fsm_en) begin
			fsm_q <= fsm_next;
		end
	end
	assign fsm_en   = valid_i | |(fsm_q); 
	assign fsm_next = final_round ? 4'b0000 : fsm_q + 4'b0001;
	// output is enabled ( valid )
	assign v_en = fsm_en & ~final_round;
	assign final_round = ( fsm_q == R );
	assign valid_o     = final_round;
endmodule
