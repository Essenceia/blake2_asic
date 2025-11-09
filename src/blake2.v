`timescale 1ns / 1ps
	 
// G Rotation | (R1, R2, R3, R4)
// constants  | (32, 24, 16, 63) 


// Main blake2 module
// default parameter configuration is for blake2b
module blake2 #(	
	parameter W      = 64, 
	parameter BB     = W*2,
	parameter R1     = 32, // rotation bits, used in G
	parameter R2     = 24,
	parameter R3     = 16,
	parameter R4     = 63,
	parameter R      = 12, // Number of rounds in v srambling
	parameter [3:0] R_LAST = R,
	parameter BB_CLOG2   = $clog2(BB),
	parameter W_CLOG2_P1 = $clog2((W+1)) // double paranthesis needed: verilator parsing bug
	)
	(
	input wire                  clk,
	input wire                  nreset,

	input wire [W_CLOG2_P1-1:0] kk_i,
	input wire [W_CLOG2_P1-1:0] nn_i,
	input wire [BB-1:0]         ll_i,

	input wire                  block_first_i,               
	input wire                  block_last_i,   
	input wire                  slow_output_i,            
	
	input wire                  data_v_i,
	input wire [BB_CLOG2-1:0]   data_idx_i,	
	input wire [7:0]            data_i,

	output wire                 ready_v_o,	
	output wire                 h_v_o,
	output wire [7:0]           h_o
	);
	localparam IB_CNT_W = BB - $clog2(BB);
	localparam RND_W    = $clog2(R);
	localparam G_RND_W  = $clog2(8);

	wire [G_RND_W-1:0] g_idx_next; // Finished sub round index
	(* MARK_DEBUG = "true" *)reg  [G_RND_W-1:0] g_idx_q; // G function idx, sub-round
	(* MARK_DEBUG = "true" *)reg  [RND_W-1:0] round_q;

	wire [BB-1:0]  t;	
	reg  [IB_CNT_W-1:0]  block_idx_plus_one_q;

	wire [W-1:0] v_init[15:0];
	wire [W-1:0] v_init_2[15:0];
	wire [W-1:0] v_current[15:0];
	reg  [W-1:0] v_q[15:0];

	wire [W-1:0] h_last[7:0];
	wire [W*8-1:0] h_shift_next;
	wire [W-1:0] h_shift_next_matrix[7:0];
	reg  [W-1:0] h_q[7:0];
	/* verilator lint_off UNUSEDSIGNAL */
	// bottom 8 bits expected to be unused
	wire [W*8-1:0] h_flat;
	/* verilator lint_on UNUSEDSIGNAL */
	
	reg  [W*16-1:0] m_q;
	wire [W-1:0] m_matrix[15:0];
		 
	wire [W-1:0] IV[0:7];
	wire [W-1:0] f_h[0:7];
	wire [W-1:0] h_init[0:7];
	wire [63:0]  SIGMA[9:0];
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
	       		

	generate /* init vector */
		if (W == 64) begin : g_iv_b 
			assign IV[0] = 64'h6A09E667F3BCC908;
			assign IV[1] = 64'hBB67AE8584CAA73B;
			assign IV[2] = 64'h3C6EF372FE94F82B;
			assign IV[3] = 64'hA54FF53A5F1D36F1;
			assign IV[4] = 64'h510E527FADE682D1;
			assign IV[5] = 64'h9B05688C2B3E6C1F;
			assign IV[6] = 64'h1F83D9ABFB41BD6B;
			assign IV[7] = 64'h5BE0CD19137E2179;
		end else begin : g_iv_s
			assign IV[0] = 32'h6A09E667;
			assign IV[1] = 32'hBB67AE85;
			assign IV[2] = 32'h3C6EF372;
			assign IV[3] = 32'hA54FF53A;
			assign IV[4] = 32'h510E527F;
			assign IV[5] = 32'h9B05688C;
			assign IV[6] = 32'h1F83D9AB;
			assign IV[7] = 32'h5BE0CD19;
		end
	endgenerate

	// fsm
	localparam [2:0] S_IDLE = 3'd0;
	localparam [2:0] S_WAIT_DATA = 3'd1;
	localparam [2:0] S_F = 3'd2;
	localparam [2:0] S_F_END = 3'd3; // write back h, save on mux on path to write back v to h
	localparam [2:0] S_F_END_2 = 3'd4; // extra cycle on slow out
	localparam [2:0] S_RES = 3'd5;

	reg first_block_q; 
	reg last_block_q; 
	reg slow_output_q; 
	(* MARK_DEBUG = "true" *) reg [2:0] fsm_q;
	wire f_finished;
	reg  f_finished_q;
	reg [W_CLOG2_P1-1:0] res_cnt_q;
	wire [W_CLOG2_P1-1:0] res_cnt_add;

	always @(posedge clk) begin
		if (~nreset) begin
			fsm_q <= S_IDLE;
		end else begin
			case (fsm_q) 
				S_IDLE: fsm_q <= data_v_i ? S_WAIT_DATA: S_IDLE;
				S_WAIT_DATA: fsm_q <= (data_v_i & (data_idx_i == 6'd63))? S_F : S_WAIT_DATA;
				S_F: fsm_q <= f_finished ? S_F_END : S_F;
				S_F_END: fsm_q <= last_block_q ? (slow_output_q ? S_F_END_2 : S_RES ): S_WAIT_DATA;
				S_F_END_2: fsm_q <= S_RES;
				S_RES: fsm_q <= res_cnt_add == nn_i ? S_IDLE: S_RES;
				default : fsm_q <= S_IDLE; 
			endcase
		end
	end

	always @(posedge clk) begin
		case (fsm_q)
			S_IDLE: slow_output_q <= 1'b0;
			default: slow_output_q <= slow_output_q | slow_output_i;
		endcase
	end

	always @(posedge clk) begin
		case (fsm_q)
			S_WAIT_DATA: begin
				first_block_q <= data_v_i ? block_first_i : first_block_q;
				last_block_q <= data_v_i ? block_last_i : last_block_q;
			end
			S_RES, S_IDLE: begin
				first_block_q <= 1'b0;
				last_block_q <= 1'b0;
			end
			default: begin
				first_block_q <= first_block_q;
				last_block_q <= last_block_q;
			end
		endcase
	end


/* `inc_g_idx` is to hold g sub cycle 4 and 7 an extra cycle to leave v[15]/v[4] time to propegate as
 * it is used in both g sub step 3->4/7->0. Just in case we needed another
 * reminder that lake2 was not design for hardware. */
	reg unused_f_cnt_q;
	wire inc_g_idx;
	assign inc_g_idx = ~((g_idx_next == 3'd3) | (g_idx_next == 3'd6)); 
	always @(posedge clk) begin
		case (fsm_q)
			S_F: {unused_f_cnt_q, round_q, g_idx_q} <= {round_q, g_idx_q} + {{RND_W+G_RND_W-1{1'b0}}, inc_g_idx};
			default: {round_q, g_idx_q} <= {RND_W+G_RND_W{1'b0}};
		endcase
	end
	assign f_finished = {round_q, g_idx_next} == { R_LAST, 3'd7};
	always @(posedge clk) begin
		f_finished_q <= f_finished;
	end

	reg unused_block_idx_plus_one_q;	
	always @(posedge clk) begin
		if ( (fsm_q == S_IDLE) | (fsm_q == S_RES)) 
			block_idx_plus_one_q <= {{IB_CNT_W-1{1'b0}}, 1'b1};
		else 
			{unused_block_idx_plus_one_q, block_idx_plus_one_q} <= block_idx_plus_one_q + {{IB_CNT_W-1{1'b0}},f_finished};
	end

	wire unused_res_cnt_add;
	reg shift_hash_q; 
	/* increments by 1 if slow ioutput isn't enabled, else 
 	*  output each 8b hash output over 2 cycles */
	always @(posedge clk) begin
		case(fsm_q)
			S_F_END: shift_hash_q <= 1'b1;
			default: shift_hash_q <= shift_hash_q ^ slow_output_q;
		endcase
	end
	
	assign {unused_res_cnt_add, res_cnt_add} = res_cnt_q + {{W_CLOG2_P1-1{1'b0}}, shift_hash_q};
	always @(posedge clk) begin
		case(fsm_q)
			S_RES: res_cnt_q <= res_cnt_add;
			default: res_cnt_q <= {W_CLOG2_P1{1'b0}};
		endcase
	end

	//-------------
	//
	// Init
	//
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
	assign h_init[0] = IV[0] ^ {{W-32{1'b0}},32'h01010000} ^ {{W-W_CLOG2_P1-8{1'b0}},  kk_i ,{8{1'b0}}} ^ {{W-W_CLOG2_P1{1'b0}} , nn_i};

	//----------
	//
	// Function F
	//
	// Calculate t
	assign t = last_block_q ? ll_i: {block_idx_plus_one_q, {BB_CLOG2{1'b0}}};
	//
	// Initialize local work vector v[0..15]
	// v[0..7]  := h[0..7]              // First half from state.
	// v[8..15] := IV[0..7]            // Second half from IV.
	genvar i_v_init;
	generate
		for(i_v_init=0;i_v_init<8;i_v_init=i_v_init+1) begin : loop_v_init
			 assign f_h[i_v_init]      = first_block_q ? h_init[i_v_init]: h_q[i_v_init]; // v[0..7] := h[0..7]
			 assign v_init[i_v_init]   = f_h[i_v_init]; // v[0..7] := h[0..7]
			 assign v_init[i_v_init+8] = IV[i_v_init];     // v[8..15] := IV[0..7]
		end
	 endgenerate
	// v[12] := v[12] ^ (t mod 2**w)   // Low word of the offset.
	// v[13] := v[13] ^ (t >> w)       // High word.
	// IF f = TRUE THEN                // last block flag?
	// |   v[14] := v[14] ^ 0xFF..FF   // Invert all bits.
	// END IF.
	assign v_init_2[12] = v_init[12] ^ t[W-1:0]; // Low word of the offset
	assign v_init_2[13] = v_init[13] ^ t[2*W-1:W];// High word of the offset
	assign v_init_2[14] = v_init[14] ^ {W{last_block_q}};
	assign v_init_2[15] = v_init[15];
	genvar v_init_2_i;
	generate
		for(v_init_2_i=0;v_init_2_i<12; v_init_2_i=v_init_2_i+1) begin : loop_v_init_2_i
			assign v_init_2[v_init_2_i] = v_init[v_init_2_i];
		end
	endgenerate


		

	genvar v_idx;
	generate
		for(v_idx = 0; v_idx<16; v_idx=v_idx+1 ) begin : loop_v_idx
			assign v_current[v_idx] = ((round_q == {RND_W{1'b0}}) & (g_idx_q < 3'd4))? v_init_2[v_idx] : v_q[v_idx];
		end
	endgenerate

	// write back v_q
	//                                               g_idx_q
	// v := G( v, 0, 4,  8, 12, m[s[ 0]], m[s[ 1]] ) 0
	// v := G( v, 1, 5,  9, 13, m[s[ 2]], m[s[ 3]] ) 1
	// v := G( v, 2, 6, 10, 14, m[s[ 4]], m[s[ 5]] ) 2
	// v := G( v, 3, 7, 11, 15, m[s[ 6]], m[s[ 7]] ) 3
	//
	// v := G( v, 0, 5, 10, 15, m[s[ 8]], m[s[ 9]] ) 4
	// v := G( v, 1, 6, 11, 12, m[s[10]], m[s[11]] ) 5
	// v := G( v, 2, 7,  8, 13, m[s[12]], m[s[13]] ) 6
	// v := G( v, 3, 4,  9, 14, m[s[14]], m[s[15]] ) 7

	reg  [W-1:0] g_a, g_b, g_c, g_d;
	wire [W-1:0] g_x, g_y;
	/* not using @(*) to work around xst limitation */
	always @(*) begin 
		case(g_idx_q[1:0])
			0: g_a = v_current[0];
			1: g_a = v_current[1];
			2: g_a = v_current[2];
			3: g_a = v_current[3];
		endcase
	end

	wire [1:0] g_b_idx;
	wire unused_g_b_idx;
	assign {unused_g_b_idx, g_b_idx} = g_idx_q[1:0] + {2'b0,g_idx_q[2]}; 
	always @(*) begin
		case(g_b_idx)
			0: g_b = v_current[4];
			1: g_b = v_current[5];
			2: g_b = v_current[6];
			3: g_b = v_current[7];
		endcase
	end

	wire [1:0] g_c_idx; 
	wire unused_g_c_idx; 
	assign {unused_g_c_idx,g_c_idx} = g_idx_q + {g_idx_q[2], 1'b0};
	always @(*) begin
		case(g_c_idx)
			0: g_c = v_current[8]; 
			1: g_c = v_current[9]; 
			2: g_c = v_current[10]; 
			3: g_c = v_current[11]; 
 		endcase
	end

	wire [1:0] g_d_idx; 
	wire unused_g_d_idx; 
	assign {unused_g_d_idx,g_d_idx} = g_idx_q + {1'b0,{2{g_idx_q[2]}}};
	always @(*) begin
		case(g_d_idx)
			0: g_d = v_current[12];
			1: g_d = v_current[13];
			2: g_d = v_current[14];
			3: g_d = v_current[15];
		endcase
	end

	assign sigma_row  = {64{ round_q == 4'd0 }} & SIGMA[0]
			 		  | {64{ round_q == 4'd1 }} & SIGMA[1]
			 		  | {64{ round_q == 4'd2 }} & SIGMA[2]
			 		  | {64{ round_q == 4'd3 }} & SIGMA[3]
			 		  | {64{ round_q == 4'd4 }} & SIGMA[4]
			 		  | {64{ round_q == 4'd5 }} & SIGMA[5]
			 		  | {64{ round_q == 4'd6 }} & SIGMA[6]
			 		  | {64{ round_q == 4'd7 }} & SIGMA[7]
			 		  | {64{ round_q == 4'd8 }} & SIGMA[8]
			 		  | {64{ round_q == 4'd9 }} & SIGMA[9];
	genvar j;
	generate
		for( j = 0; j < 16; j=j+1 ) begin : loop_sigma_elem
			assign sigma_row_elems[j] = sigma_row[j*4+3:j*4];
		end
	endgenerate

	reg [3:0] g_x_idx, g_y_idx;
	always @(*) begin
		case(g_idx_q)
			0: {g_x_idx, g_y_idx} = {sigma_row_elems[0], sigma_row_elems[1]};
			1: {g_x_idx, g_y_idx} = {sigma_row_elems[2], sigma_row_elems[3]};
			2: {g_x_idx, g_y_idx} = {sigma_row_elems[4], sigma_row_elems[5]};
			3: {g_x_idx, g_y_idx} = {sigma_row_elems[6], sigma_row_elems[7]};
			4: {g_x_idx, g_y_idx} = {sigma_row_elems[8], sigma_row_elems[9]};
			5: {g_x_idx, g_y_idx} = {sigma_row_elems[10], sigma_row_elems[11]};
			6: {g_x_idx, g_y_idx} = {sigma_row_elems[12], sigma_row_elems[13]};
			7: {g_x_idx, g_y_idx} = {sigma_row_elems[14], sigma_row_elems[15]};
		endcase
	end
	assign g_x = m_matrix[g_x_idx];
	assign g_y = m_matrix[g_y_idx];
	
	wire [W-1:0] a,b,c,d; 
	
	G #(.W(W), .R1(R1), .R2(R2), .R3(R3), .R4(R4)) 
	m_g(
		.clk(clk),
		
		.g_idx_i(g_idx_q),
		.g_idx_o(g_idx_next),

		.a_i(g_a),
		.b_i(g_b),
		.c_i(g_c),
		.d_i(g_d),
		.x_i(g_x),
		.y_i(g_y),
		.a_o(a),
		.b_o(b),
		.c_o(c),
		.d_o(d)
	);

	always @(posedge clk) begin
		if (fsm_q == S_F) begin
			if ((g_idx_next == 'd0) | (g_idx_next == 'd4))
				v_q[0] <= a;
			if ((g_idx_next == 'd1) | (g_idx_next == 'd5))
				v_q[1] <= a;	
			if ((g_idx_next == 'd2) | (g_idx_next == 'd6))
				v_q[2] <= a;		
			if ((g_idx_next == 'd3) | (g_idx_next == 'd7))
				v_q[3] <= a;
			if ((g_idx_next == 'd0) | (g_idx_next == 'd7))
				v_q[4] <= b;	
			if ((g_idx_next == 'd1) | (g_idx_next == 'd4))
				v_q[5] <= b;	
			if ((g_idx_next == 'd2) | (g_idx_next == 'd5))
				v_q[6] <= b;	
			if ((g_idx_next == 'd3) | (g_idx_next == 'd6))
				v_q[7] <= b;	
			if ((g_idx_next == 'd0) | (g_idx_next == 'd6))
				v_q[8] <= c;	
			if ((g_idx_next == 'd1) | (g_idx_next == 'd7))
				v_q[9] <= c;	
			if ((g_idx_next == 'd2) | (g_idx_next == 'd4))
				v_q[10] <= c;	
			if ((g_idx_next == 'd3) | (g_idx_next == 'd5))
				v_q[11] <= c;			
			if ((g_idx_next == 'd0) | (g_idx_next == 'd5))
				v_q[12] <= d;	
			if ((g_idx_next == 'd1) | (g_idx_next == 'd6))
				v_q[13] <= d;	
			if ((g_idx_next == 'd2) | (g_idx_next == 'd7))
				v_q[14] <= d;	
			if ((g_idx_next == 'd3) | (g_idx_next == 'd4))
				v_q[15] <= d;	
		end	
	end



	always @(posedge clk)
	begin
		if(data_v_i)
			m_q <= {data_i, m_q[511:8]};
	end

	genvar i_m_q;
	generate
		for(i_m_q=0; i_m_q<16; i_m_q=i_m_q+1 ) begin : loop_i_m_q
			assign m_matrix[i_m_q] = m_q[(i_m_q+1)*W-1:i_m_q*W];
		end
	endgenerate
		
	// FOR i = 0 TO 7 DO               // XOR the two halves.
	// |   h[i] := h[i] ^ v[i] ^ v[i + 8]
	// END FOR.
	generate
		for(h_idx=0; h_idx<8; h_idx=h_idx+1 ) begin : loop_h_o
			assign h_last[h_idx] = f_h[h_idx] ^ v_q[h_idx] ^ v_q[h_idx+8];
			assign h_flat[(h_idx+1)*W-1:h_idx*W] = h_q[h_idx];
			assign h_shift_next_matrix[h_idx] = h_shift_next[(h_idx+1)*W-1:h_idx*W];

			always @(posedge clk) 
				if (f_finished_q) 
					h_q[h_idx] <= h_last[h_idx];
				else if ((fsm_q == S_RES) & shift_hash_q) 
					h_q[h_idx] <= h_shift_next_matrix[h_idx];
		end
	endgenerate

	assign h_shift_next = {8'b0, h_flat[W*8-1:8]};

	// output 
	
	// ready 
	assign ready_v_o = ((fsm_q == S_WAIT_DATA) | (fsm_q == S_IDLE));	

	// hash finished result streaming
	// assert h_v_o one ( or two of slow output enabled ) cycle early to trigger PR2040 PIO wait instruction 
	assign	h_o   = h_q[0][7:0];
	assign	h_v_o = (fsm_q == S_RES) | ((fsm_q == S_F_END) & last_block_q) | (fsm_q == S_F_END_2);

endmodule
