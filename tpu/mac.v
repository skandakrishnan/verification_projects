/*
/ Module Name : mac
/ Author : Skanda Krishnan B
/
/ Description : Module to multiply and accumulate. 
/               Clocked module with 3 data paths flipflopped
*/

module mac(
	output reg [23:0] pout,
	output reg dv_pout,
	output reg [7:0] aout,
	output reg dv_aout,
	output reg [7:0] wout,
	output reg dv_wout,
	input [7:0] ain,
	input dv_ain,
	input [7:0] win,
	input dv_win,
	input init_win,
	input [23:0] pin,
	input dv_pin,
	input dv_mult,
	input clk,
	input rst
);

reg [7:0] ff_a,ff_w;
//reg [15:0] ff_pw,ff_pa;
reg [15:0] prod;

always @(posedge clk or posedge rst) begin
	if(rst) begin
		aout <= 8'd0;
		dv_aout <= 1'b0;
	end
	else if(dv_ain)begin
		aout <= ain;
		dv_aout <= 1'b1;
	end
	else begin 
		aout <= 8'd0;
		dv_aout <= 1'b0;
	end
end


always @(*)
	 ff_a <= aout;

always @(posedge clk or posedge rst) begin
	if(rst)begin 
		wout <= 8'd0;
		dv_wout <= 1'b0;
	end
	else if(init_win)begin
		wout <= win;
		dv_wout <= dv_win;
	end
	       	       


end


always @(*)
        ff_w <= wout;


//assign ff_pw = {8'd0,ff_w};
//assign ff_pa = {8'd0,ff_a};

always @(*)begin
	prod <= {8'd0,ff_w} * {8'd0,ff_a};
end
        
always @(posedge clk or posedge rst)begin
//	if(dv_aout && dv_wout && dv_pin)begin
	if(dv_aout && dv_wout)begin
        pout <= {8'd0,prod} + pin;
       	dv_pout <= 1'b1;	
	end
	else begin 
		pout <= 24'd0;
		dv_pout <= 1'b0;
	end
end


endmodule
