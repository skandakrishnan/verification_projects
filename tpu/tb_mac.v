module stimulus;
reg [7:0] ain,win;
reg dv_ain,dv_win,dv_pin,init_win,clk,rst;
reg [23:0]pin;

wire dv_pout,dv_aout,dv_wout;
wire [7:0] wout,aout;
wire [23:0] pout;

mac m1( .clk      (clk),
 	.rst      (rst),
	.dv_ain   (dv_ain),
	.ain      (ain),
	.dv_win   (dv_win),
	.win      (win),
	.init_win (init_win),
	.dv_pin   (dv_pin),
	.pin      (pin),
	.dv_aout  (dv_aout),
	.aout     (aout),
	.dv_wout  (dv_wout),
	.wout     (wout),
	.dv_pout  (dv_pout),
	.pout     (pout)
);

	

initial begin
	clk = 1'b0;
end

always
	#5 clk = ~clk;

initial begin
	   rst = 1'b0;
	#5 rst = 1'b1;
	#5 rst = 1'b0;

        #5

	#5 dv_win = 1'b1;
	   win = 8'd3;
	   init_win = 1'b1;
	
	#10
       	   init_win = 1'b0;	
	   pin = 24'd0;
	   dv_pin = 1'b1;
	   ain = 8'd0;
	   dv_ain = 1'b1;



	#10 pin = 24'd1;
	   dv_pin = 1'b1;
	   ain = 8'd1;
	   dv_ain = 1'b1;

        #10 pin = 24'd2;
	   dv_pin = 1'b1;
	   ain = 8'd2;
	   dv_ain = 1'b1;

	 
     	   
	
end
initial begin
#1000
	$display($time,"\n win =                 %d\n ain =                 %d\n pin =            %d\n pout = (w*a)+p = %d\n",win,ain,pin,pout);

	$dumpfile("wave_mac.vcd");
	$dumpvars(0,stimulus);
	$finish;

end
endmodule
