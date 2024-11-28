module stimulus;

reg [31:0] acin;
reg [3:0] dv_acin;
reg clk,rst;
wire  dv_acout;
wire [127:0] acout;

activ a1( 
	.rst(rst),
	.dv_acin(dv_acin),
	.acin(acin),
	.dv_acout(dv_acout),
	.acout(acout)
);


initial begin
	clk = 1'b0;
end



initial begin
	#5 rst = 1'b1;
	   dv_acin = 4'b0000;
	#30 rst = 1'b0;

	#10 dv_acin = 4'b1111;
  	    acin[31:24] = 8'd11;
	    acin[23:0]  = 24'd0;

	#20 
  	    acin[31:24] = 8'd11;
	    acin[23:16] = 8'd9;
	    acin[15:8]  = 8'd9;
	    acin[7:0]   = 8'd11;

	#20 
  	    acin[31:24] = 8'd9;
	    acin[23:16] = 8'd11;
	    acin[15:8]  = 8'd11;
	    acin[7:0]   = 8'd9;
	    
	#20 
  	    acin[31:24] = 8'd100;
	    acin[23:16] = 8'd1;
	    acin[15:8]  = 8'd100;
	    acin[7:0]   = 8'd1;
	
    
	#20 
  	    acin[31:24] = 8'd11;
	    acin[23:16] = 8'd11;
	    acin[15:8]  = 8'd11;
	    acin[7:0]   = 8'd11;

	#20 
  	    acin[31:24] = 8'd110;
	    acin[23:16] = 8'd110;
	    acin[15:8]  = 8'd110;
	    acin[7:0]   = 8'd110;


	#20 
  	    acin[31:24] = 8'd11;
	    acin[23:16] = 8'd11;
	    acin[15:8]  = 8'd11;
	    acin[7:0]   = 8'd11;

	#20 
  	    acin[31:24] = 8'd11;
	    acin[23:16] = 8'd11;
	    acin[15:8]  = 8'd11;
	    acin[7:0]   = 8'd11;
	#200
	$finish;

end
initial begin
#65
	$monitor($time,"\n data_valid = %b \n acin0 = %d, acout0 = %d\n acin1 = %d, acout1 = %d\n acin2 = %d, acout2 = %d\n acin3 = %d, acout3 = %d",dv_acin,acin[7:0],acout[31:24],acin[15:8],acout[55:48],acin[23:16],acout[79:72],acin[31:24],acout[103:96]);

	$dumpfile("wave_activ.vcd");
	$dumpvars(0,stimulus);

end
always 
	#10 clk = ~clk;
endmodule
