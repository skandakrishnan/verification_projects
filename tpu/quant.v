/*
/ Module Name : quant
/ Author : Skanda Krishnan B
/
/ Description : Module to upper bound the data 
/               If input greater than 255 output is locked to 255
/               else output is equal to the input
*/


module quant(
	input             rst,
	input      [3:0]  dv_pin,
	input      [95:0] pin,
	output reg [31:0] qout,
        output reg [3:0]  dv_qout
);


genvar i;
generate 
	for(i =0;i<4;i=i+1) begin
		always @(*) begin
			if (rst) begin
				qout[(i*8)+7:(i*8)] <= 8'd0;
				dv_qout[i] <= 1'b0;
			end
			else if(dv_pin[i]) begin
				if(pin[(i*24)+23:(i*24)] <=24'd255)
					qout[(i*8)+7:(i*8)] <= pin[(i*24)+7:(i*24)];
				else
					qout[(i*8)+7:(i*8)] <= 8'd255;
	 			dv_qout[i] <= dv_pin[i];
			end
			else begin
				qout[(i*8)+7:(i*8)] <= 8'd0;
				dv_qout[i] <= 1'b0;
			end
		end
	end
endgenerate

endmodule
