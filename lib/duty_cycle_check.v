/*
 * duty_cycle_check.v: This module determines the duty cycle of the input
 * 	signal and compares it against the desired duty cycle.
 * author: Till Mahlburg
 * year: 2020
 * organization: Universität Leipzig
 * license: ISC
 *
 */

`timescale 1 ns / 1 ps

module duty_cycle_check (
	/* duty cycle multiplied by 1000 (500 for 50 % in high) */
	input [31:0] desired_duty_cycle_1000,
	input [31:0] clk_period_1000,
	input clk,
	input reset,
	input LOCKED,

	/* 0 - clk duty cycle matches desired_duty_cycle
	 * 1 - clk duty cycle does not match the desired_duty_cycle
	 */
	output reg fail);

	always @(posedge clk or posedge reset) begin
		if (reset) begin
			fail <= 0;
		end else if (LOCKED) begin
			#(((clk_period_1000 / 1000.0) * (desired_duty_cycle_1000 / 1000.0)) - 0.1);
			if (clk != 1) begin
				fail <= 1;
			end
			#0.2;
			if (clk != 0) begin
				fail <= 1;
			end
		end else begin
			fail <= 0;
		end
	end
endmodule
