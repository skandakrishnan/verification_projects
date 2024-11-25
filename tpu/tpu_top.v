/*
/ Module Name : quant
/ Author : Skanda Krishnan B
/
/ Description : Module to do a 4x4 matrix multiplication
/               uses MAC, quant and activ as submodules
/               houses a total of 48 bytes of memory and a memory control rtl to go through the statemachine
*/
`define a_mem 1
`define w_mem 2
`define p_mem 3

module tpu_top(
	input clk,
	input rst,
	input [7:0] data_in,
	input [3:0] wr_addr,
	input [1:0] mem_acc,
	input [3:0] rd_addr,
	input dv_a,
	input [127:0] w,
	input dv_w,
	input start,
	output reg [7:0] data_out,
	output reg [127:0] p,
	output reg dv_p,
	output reg busy
);
reg [127:0] r_w,r_a;
 
reg [7:0] a_data [31:0];
reg [7:0] w_data [15:0];
wire [7:0] p_data [15:0];


wire [23:0] mac_pdata[19:0];
wire [19:0]mac_pdv;

wire [7:0] mac_adata[19:0];
wire [19:0]mac_adv;

wire [7:0] mac_wdata[19:0];
wire [19:0]mac_wdv;

wire [127:0] act_data;

wire [95:0] sys_data;
wire [3:0]sys_dv;
reg [1:0] init_cnt;
always @(posedge clk) begin
	if(mem_acc == `a_mem)
		a_data[wr_addr] <= data_in;
end

always @(posedge clk) begin
	if(mem_acc == `w_mem)
		w_data[wr_addr] <= data_in;
end


always @(posedge clk) begin
	if(mem_acc == `p_mem)
		data_out <= p_data[rd_addr];
end

genvar k;
generate 
	for(k =0;k<16;k=k+1)begin
//		always @(*) begin
		     assign  p_data[k] = act_data[(8*k)+7:(8*k)];
	//       end
      	always @(*) begin
		     a_data[16+k] <= act_data[(8*k)+7:(8*k)];
        end

	end
	for(k=0;k<4;k=k+1)begin
		assign mac_pdata[k*5] = 24'd0;
		assign mac_pdv [k*5] = 1'b1;
	end
endgenerate



wire proc_done;
wire [31:0] quant_dout;
wire [3:0] quant_dvout;


activ a1(.acout(act_data),
	.dv_acout(proc_done),
	.acin(quant_dout),
	.dv_acin(quant_dvout),
	.rst(rst)
);



quant q1(.rst(rst),
	.dv_pin(sys_dv),
	.pin(sys_data),
	.qout(quant_dout),
	.dv_qout(quant_dvout)
);
reg init_win;
reg dv_mult;
genvar m,j;
generate
	for(m=0;m<4;m=m+1)begin
		for(j=0;j<4;j=j+1)begin 
		  mac mc(
			  .pout(mac_pdata[(j*5)+m+1]),
			  .dv_pout(mac_pdv[(j*5)+m+1]),
			  .aout(mac_adata[(m*5)+j+1]),
			  .dv_aout(mac_adv[(m*5)+j+1]),
			  .wout(mac_wdata[(j*5)+m+1]),
			  .dv_wout(mac_wdv[(j*5)+m+1]),
			  .ain(mac_adata[(m*5)+j]),
			  .dv_ain(mac_adv[(m*5)+j]),
			  .win(mac_wdata[(j*5)+m]),
			  .dv_win(mac_wdv[(j*5)+m]),
			  .init_win(init_win),
			  .pin(mac_pdata[(j*5)+m]),
	 		  .dv_pin(mac_pdv[(j*5)+m]),
			  .dv_mult(dv_mult),
			  .clk(clk),
			  .rst(rst)
		  );
		end
//		assign mac_pdata [m*5]= 24'd0;
//		assign mac_pdv [m*5] = 1'b0;
		assign sys_data[(m*24)+23:m*24] = mac_pdata [(m*5)+4];
		assign sys_dv[m] = mac_pdv[(m*5)+4];
		assign mac_wdata[m*5] = w_data[(m*4) - init_cnt + 3];
		assign mac_wdv[m*5] = init_win;

	end
endgenerate


reg [3:0] mul_cnt;
always @(posedge clk or posedge rst) begin
	if(rst)begin
		init_cnt <= 2'd3;
		init_win <= 1'b0;
	end
	else if(busy && start && (init_cnt ==2'd3))begin
		init_cnt <= init_cnt+1;
		init_win <= 1'b1;
	end
	else if(init_win)begin
		if(init_cnt == 2'd3)
			init_win <= 1'b0;
		else
	 		init_cnt <= init_cnt+1;
	end
end
	

reg multiply;
always@(*) begin
	if(rst) 
		multiply <= 1'b0;
	else if(busy && mac_wdv[4])
		multiply <=1'b1;
	else if(mul_cnt == 4'd10)
		multiply <=1'b0;
	else
		multiply <= multiply;
end

always@(posedge clk or posedge rst)begin
	if(rst)
		mul_cnt <= 4'd0;
	else if(multiply)
		mul_cnt <= mul_cnt +1;
	else
		mul_cnt <= 4'd0;
end
reg [7:0] mac_ad[3:0];
reg [3:0] mac_radv;
//assign mac_adata[0] = mac_ad_0;
assign mac_adata[0] = mac_ad[0];
assign mac_adata[5] = mac_ad[1];
assign mac_adata[10] = mac_ad[2];
assign mac_adata[15] = mac_ad[3];
assign mac_adv[0] = mac_radv[0];
assign mac_adv[5] = mac_radv[1];
assign mac_adv[10] = mac_radv[2];
assign mac_adv[15] = mac_radv[3];
//assign mac_adata[10] = mac_ad_10;
//assign mac_adata[15] = mac_ad_15;

always @(*)begin
	if(rst)begin 
		mac_radv[0] <= 1'b0;
	end
	else if(multiply && (mul_cnt<=3))begin
		mac_radv[0] <= 1'b1;
		mac_ad[0] <= a_data[mul_cnt];
	end
	else
		mac_radv[0] <= 1'b0;
end

always @(*) begin
	if(rst)begin 
		mac_radv[1] <= 1'b0;
	end
	else if(multiply &&(mul_cnt>=1)&&(mul_cnt<=4))begin
		mac_radv[1] <= 1'b1;
		mac_ad[1] <= a_data[mul_cnt+4'd3];
	end
	else
		mac_radv[1] <= 1'b0;
end
	
	
always @(*) begin
	if(rst)begin 
		mac_radv[2] <= 1'b0;
	end
	else if(multiply &&(mul_cnt>=2)&&(mul_cnt<=5))begin
		mac_radv[2] <= 1'b1;
		mac_ad[2] <= a_data[mul_cnt+4'd6];
	end
	else
		mac_radv[2] <= 1'b0;
end


	
always @(*) begin
	if(rst)begin 
		mac_radv[3] <= 1'b0;
	end
	else if(multiply &&(mul_cnt>=3)&&(mul_cnt<=6))begin
		mac_radv[3] <= 1'b1;
		mac_ad[3] <= a_data[mul_cnt+4'd9];
	end
	else
		mac_radv[3] <= 1'b0;
end






always@(*) begin
	if(rst)
		busy <= 1'b0;
	else if(start)
		busy <= 1'b1;
	else if(proc_done)
		busy <= 1'b0;
	else
		busy <= busy;
end




endmodule
