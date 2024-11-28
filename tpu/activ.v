/*
/ Module Name : activ
/ Author : Skanda Krishnan B
/
/ Description : Module to lower bound the data. If less than 10 output would be 0 
/               else ouptut is same as input
*/
module activ(
	output  reg [127:0] acout,
	output reg dv_acout,
	input [31:0] acin,
	input [3:0] dv_acin,
	input rst
);
reg [31:0] actdata;
reg [15:0] dv_ac;
genvar l;
generate 
	for(l =0;l <4;l=l+1)begin
		always @(*)begin
			if(acin [(l*8)+7:l*8] > 8'd10)
		                actdata [(l*8)+7:l*8] <= acin [(l*8)+7:l*8];
			else
				
		                actdata [(l*8)+7:l*8] <= 8'd0;
		end
	end
endgenerate
always @(*) begin
	case (dv_acin)
		4'b0001 : begin 
		            acout[7:0] <= actdata[7:0];
			    dv_ac[0]   <= 1'b1;
			  end

		4'b0011 : begin 
		            acout[15:8] <= actdata[7:0];
		            dv_ac[1]   <= 1'b1;
			    acout[39:32] <= actdata[15:8];
			    dv_ac[4]   <= 1'b1;
	                  end

		4'b0111 : begin 
		            acout[23:16] <= actdata[7:0];
		            dv_ac[2]   <= 1'b1;
			    acout[47:40] <= actdata[15:8];
			    dv_ac[5]   <= 1'b1;
			    acout[71:64] <= actdata[23:16];
			    dv_ac[8]   <= 1'b1;
			  end
	      
	     4'b1111 : begin 
		            acout[31:24] <= actdata[7:0];
		            dv_ac[3]   <= 1'b1;
			    acout[55:48] <= actdata[15:8];
			    dv_ac[6]   <= 1'b1;
			    acout[79:72] <= actdata[23:16];
			    dv_ac[9]   <= 1'b1;
			    acout[103:96] <= actdata[31:24];
			    dv_ac[12]  <= 1'b1;
		          end

		4'b1110 : begin 
		            acout[63:56] <= actdata[15:8];
		            dv_ac[7]   <= 1'b1;
			    acout[87:80] <= actdata[23:16];
			    dv_ac [10]  <= 1'b1;
			    acout[111:104] <= actdata[31:24];
			    dv_ac[13]  <= 1'b1;
			  end

		4'b1100 : begin 
		            acout[95:88] <= actdata[23:16];
		            dv_ac [11]  <= 1'b1;
			    acout[119:112] <= actdata[31:24];
			    dv_ac [14] <= 1'b1;
			  end

		4'b1000 : begin 
		            acout[127:120] <= actdata[31:24];
		            dv_ac [15] <= 1'b1;
		          end

	        default : begin 
		            acout <= acout;
			    dv_ac <= 16'd0;
		          end
	endcase
end


always@(*)
	dv_acout <= &(dv_ac);


endmodule
