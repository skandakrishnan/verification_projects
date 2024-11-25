module stimulus;
reg clk,rst,dv_a,dv_w,start;
reg[1:0] mem_acc;
reg [3:0]wr_addr,rd_addr;
reg [7:0] data_in;
reg [3:0] y;
wire [7:0] data_out;
wire dv_p;
wire busy;
tpu_top am1(
	.clk(clk),
	.rst(rst),
	.data_in(data_in),
	.wr_addr(wr_addr),
	.mem_acc(mem_acc),
	.rd_addr(rd_addr),
	.dv_a(dv_a),
	.dv_w(dv_w),
	.dv_p(dv_p),
	.start(start),
	.data_out(data_out),
	.busy(busy)
);

reg [7:0]a[15:0];
reg [7:0]w[15:0];
reg [7:0]p[15:0];
initial begin
	a[0]  = 8'd4; a[1]  = 8'd0; a[2]  = 8'd2; a[3]  = 8'd1;
	a[4]  = 8'd4; a[5]  = 8'd3; a[6]  = 8'd2; a[7]  = 8'd0;
	a[8]  = 8'd4; a[9]  = 8'd3; a[10] = 8'd0; a[11] = 8'd1;
	a[12] = 8'd4; a[13] = 8'd3; a[14] = 8'd2; a[15] = 8'd1;

	w[0]  = 8'd1; w[1]  = 8'd2; w[2]  = 8'd3; w[3]  = 8'd4;
	w[4]  = 8'd1; w[5]  = 8'd2; w[6]  = 8'd3; w[7]  = 8'd4;
	w[8]  = 8'd1; w[9]  = 8'd2; w[10] = 8'd3; w[11] = 8'd4;
	w[12] = 8'd1; w[13] = 8'd2; w[14] = 8'd3; w[15] = 8'd4;
end


initial begin
	clk = 1'b0;
	rst = 1'b0;
end
reg [3:0] count;
reg start_a;
reg start_w;
reg start_p;

initial begin
	#5
	rst = 1'b1;
	start = 1'b0;
	#20
	rst = 1'b0;
	#10
	start_a = 1'b1;
	#20
	wait(count == 4'd0)
	start_a = 1'b0;
	#20
	start_w = 1'b1;
	#20
	wait(count == 4'd0)
	start_w = 1'b0;
	#10
	start = 1'b1;
	#10
	start = 1'b0;

	#200
	start_p = 1'b1;
	#20
	wait(count == 4'd0)
	start_p = 1'b0;
	#15
	rst = 1'b1;


end

always @(negedge clk) begin
	if(rst)
		count <= 0;
	else if(start_a || start_w || start_p)
		count <= count+1;
	else
	    count <= 4'd0; 
end
always @(negedge clk) begin
	if(rst)begin
		wr_addr <= 4'd0;
		data_in <= 8'd0;
		mem_acc <= 2'b00;
	end
	else if(start_a)begin
		wr_addr <= count;
		mem_acc <= 2'b01;
		data_in <= a[count];
	end
	else if(start_w)begin
		wr_addr <= count;
		mem_acc <= 2'b10;
		data_in <= w[count];
	end
	else if(start_p)begin
		rd_addr <= count;
		mem_acc <= 2'b11;
                p[count-1] <= data_out;
	end
	else
	   p[15] <= data_out;
end
			


initial begin
#2600
	$display("\n W_matrix = %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d \n\n A_Matrix = %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d \n\n P_Matrix = %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d \n            %d %d %d %d",w[0],w[1],w[2],w[3],w[4],w[5],w[6],w[7],w[8],w[9],w[10],w[11],w[12],w[13],w[14],w[15],a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10],a[11],a[12],a[13],a[14],a[15],p[0],p[1],p[2],p[3],p[4],p[5],p[6],p[7],p[8],p[9],p[10],p[11],p[12],p[13],p[14],p[15]);

	$dumpfile("wave_tpu_top.vcd");
	$dumpvars(0,stimulus);
	$finish;
end
always 
	#5 clk = ~clk;
endmodule
