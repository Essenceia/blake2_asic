module debounce  #(
    parameter W=1, 
    parameter N=3, 
    parameter CNT_W=12
)(
    input wire clk,
    input wire rst_async,
    input wire [W-1:0] switch_i,
    output wire [W-1:0] switch_o
);

reg [CNT_W-1:0] cnt_reg;
reg [N-1:0] debounce_reg[W-1:0];
reg [W-1:0] state;
integer k;

/* sample the switch status at a defined time interval and
 * ouput new value if sampled state is stable over N samples */
always @(posedge clk or posedge rst_async) begin
    if (rst_async) begin
        cnt_reg <= {CNT_W{1'b0}};
        state <= 0;
        
        for (k = 0; k < W; k = k + 1) begin
            debounce_reg[k] <= 0;
        end
    end else begin
        cnt_reg <= cnt_reg + {{CNT_W-1{1'b0}}, 1'b1};
        
        if (cnt_reg == {CNT_W{1'b0}}) begin
            for (k = 0; k < W; k = k + 1) begin
                debounce_reg[k] <= {debounce_reg[k][N-2:0], switch_i[k]};
            end
        end
        
        for (k = 0; k < W; k = k + 1) begin
            if (|debounce_reg[k] == 0) begin
                state[k] <= 0;
            end else if (&debounce_reg[k] == 1) begin
                state[k] <= 1;
            end else begin
                state[k] <= state[k];
            end
        end
    end
end
assign switch_o = state;

endmodule

