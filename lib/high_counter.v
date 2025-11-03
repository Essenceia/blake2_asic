/*
 * high_counter.v: Counts all highs in the input signal since the last release of the rst signal.
 * author: Till Mahlburg
 * year: 2019
 * organization: Universität Leipzig
 * license: ISC
 *
 */

module high_counter (
	input	clk,
	input 	rst,

	output reg [31:0] count);

	always @(posedge rst or posedge clk) begin
		if (rst) begin
			count <= 0;
		end else begin
			count <= count + 1;
		end
	end
endmodule

