module uarttx 
  #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
  )
  (
    input clk,
    input rst,
    input newd,
    input [7:0] tx_data,
    output reg tx,
    output reg done_tx
  );
  
  localparam clkcount = (clk_freq/baud_rate);
  
  integer count = 0;
  integer counts = 0;
  
  reg uclk = 0;
  
  enum bit[1:0] {
    idle     = 2'b00,
    start    = 2'b01,
    transfer = 2'b10,
    done     = 2'b11
  } state;
  
  /// uart_clk_gen
  
  always@(posedge clk)begin
    if(count < clkcount /2)
      count <= count +1;
    else begin
      count <= 0;
      uclk <= ~uclk;
    end
  end
  
  reg [7:0] din;
  
  
  /////reset decoder
  
  always @(posedge uclk) begin
    if(rst)
      state <= idle;
    else begin
      case(state)
        idle : begin
          counts <= 0;
          tx <= 1'b1;
          done_tx <= 1'b0;
          if(newd)begin
            state <= transfer;
            din <= tx_data;
           
            tx <= 1'b0;            /// start bit in uart tx
          end
          else
            state <= idle;
        end
        
        transfer : begin
          if(counts <= 7) begin
            counts <= counts +1;
            tx <= din[counts];
            state <= transfer;
          end
          else begin
            count <= 0;
            tx <= 1'b1;          /// end bit in yuart tx
            state <= idle;   
            done_tx <= 1'b1;
          end
        end
        default : state <= idle;
        
      endcase
    end
  end
  
  
endmodule