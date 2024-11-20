module uartrx
  #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
  )
  (
    input clk,
    input rst,
    input rx,
    output reg [7:0] rx_data,
    output reg done_rx
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
       
  always @(posedge uclk) begin
    if(rst) begin
      rx_data <= 8'h00;
      counts <= 0;
      done_rx <= 1'b0;
    end
    else begin
      case(state)
        idle : begin
          rx_data <= 8'h00;
          counts <= 0;
          done_rx <= 1'b0;
          if(rx == 1'b0)
            state <= start;
          else
            state <= idle;
        end
        
        start : begin
          if(counts <=7) begin
            counts <= counts +1;
            rx_data <= {rx, rx_data[7:1]};
          end
          else begin
            counts <= 0;
            done_rx <= 1'b1;
            state <= idle;
          end
        end
        default : state <= idle;
      endcase
    end
  end
  
endmodule
