/* error detection module */ 
module error(
	input wire clk, 
	input wire nreset,

	input wire [7:0] uio_oe, 
	input wire [7:0] uio_out,

	output wire error_o
);
reg  err_q;
wire err_next;
wire switch_conf_err; 
wire unexpected_out; 

assign switch_conf_err = ~(uio_oe == 8'b10001000);
assign unexpected_out = |(~uio_oe & uio_out);
assign err_next = switch_conf_err | unexpected_out; 

always @(posedge clk)
	if (~nreset) 
		err_q <= 1'b0;
	else
		err_q <= err_q | err_next; // sticky error bit

assign error_o = err_q; 
endmodule
