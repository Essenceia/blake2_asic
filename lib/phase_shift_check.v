/*
 * phase_shift_check.v: Helper module to check the phase shift of an input
 *	signal (clk_shifted) relative to another signal (clk) and compare it
 *	with the desired shift.
 * author: Till Mahlburg
 * year: 2020
 * organization: Universität Leipzig
 * license: ISC
 *
 */

`timescale 1 ns / 1 ps

/* checks the phase shift of the input signal in relation to clk */
module phase_shift_check (
	input [31:0] desired_shift_1000,
	input [31:0] clk_period_1000,
	input clk_shifted,
	input clk,
	input rst,
	/* input to tell the module, that the inputs are ready */
	input LOCKED,
	output reg fail);

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			fail <= 0;
		end else if (LOCKED) begin
			if (desired_shift_1000 > 0) begin
				#(((desired_shift_1000 / 1000.0) * ((clk_period_1000 / 1000.0) / 360.0)) - 0.1);
				if (clk_shifted !== 0) begin
					fail <= 1;
				end
			end else if (desired_shift_1000 < 0) begin
				#(((clk_period_1000 / 1000.0) + ((desired_shift_1000 / 1000.0) * ((clk_period_1000 / 1000.0) / 360.0))) - 0.1);
				if (clk_shifted !== 0) begin
					fail <= 1;
				end
			end
			#0.2;
			if (clk_shifted !== 1 && desired_shift_1000 !== 0) begin
				fail <= 1;
			end
		end
	end
endmodule
