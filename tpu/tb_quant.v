module stimulus;

reg [95:0] pin;
reg [3:0] dv_pin;
reg clk,rst;
wire [3:0] dv_qout;
wire [31:0] qout;

quant q1( 
	.rst(rst),
	.dv_pin(dv_pin),
	.pin(pin),
	.dv_qout(dv_qout),
	.qout(qout)
);


initial begin
	clk = 1'b0;
end



initial begin
	#5 rst = 1'b1;
	   dv_pin = 4'b0000;
	#30 rst = 1'b0;

	#10 dv_pin = 4'b1111;


	#20 pin[23:0]  <= 24'd30;	
	    pin[47:24] <= 24'd30;
	    pin[71:48] <= 24'd30;
	    pin[95:72] <= 24'd30;
	   // dv_pin = 4'b0101;

	#20 pin[23:0] <= 24'd300;
	    pin[47:24] <= 24'd300;
	    pin[71:48] <= 24'd300;
	    pin[95:72] <= 24'd300;

	#20 pin[23:0] <= 24'd100;
	    pin[47:24] <= 24'd200;
	    pin[71:48] <= 24'd300;
	    pin[95:72] <= 24'd400;
	#200
	$finish;

end
initial begin
#65
	$monitor($time,"\npin0 = %d, qout0 = %d\npin1 = %d, qout1 = %d\npin2 = %d, qout2 = %d\npin3 = %d, qout3 = %d",pin[23:0],qout[7:0],pin[47:24],qout[15:8],pin[71:48],qout[23:16],pin[95:72],qout[31:24]);

	$dumpfile("wave_quant.vcd");
	$dumpvars(0,stimulus);

end
always 
	#10 clk = ~clk;
endmodule
