// Code your design here
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
  
  wire [8:0] data_w;
  reg [7:0] din;
  reg parity;
  
  assign data_w = {parity, din};
  
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
            parity <= ~^tx_data;
            tx <= 1'b0;            /// start bit in uart tx
          end
          else
            state <= idle;
        end
        
        transfer : begin
          if(counts <= 8) begin
            counts <= counts +1;
            tx <= data_w[counts];
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


module uart_top
  #(
    parameter clk_freq = 1000000,
    parameter baud_rate = 9600
  )    (
    input clk,
    input rst,
    input newd,
    input rx,
    input [7:0] dintx,
    output tx,
    output [7:0] doutrx,
    output donetx,
    output donerx
  );
  
  uarttx
  #(.clk_freq(clk_freq),
    .baud_rate(baud_rate)
   )
  utx(
    .clk(clk),
    .rst(rst),
    .newd(newd),
    .tx_data(dintx),
    .tx(tx),
    .done_tx(donetx)
  );
  
  uartrx
  #(.clk_freq(clk_freq),
    .baud_rate(baud_rate)
   )
  rtx(
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .done_rx(donerx),
    .rx_data(doutrx)
  );
  
endmodule


interface uart_if;
  logic clk;
  logic rst;
  logic rx;
  logic [7:0] dintx;
  logic newd;
  logic tx;
  logic [7:0] doutrx;
  logic donetx;
  logic donerx;
  logic uclktx;
  logic uclkrx;
endinterface
          
  
  
        
  
  