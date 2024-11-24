// Code your design here

module i2c_master(
  input clk,
  input rst,
  input newd,
  input [6:0] addr,
  input op,
  inout sda,
  output scl,
  input [7:0] din,
  output [7:0] dout,
  output reg busy,
  output reg ack_err,
  output reg done
);
  
  reg scl_t = 0;
  reg sda_t = 0;
  
  parameter sys_freq = 40000000; //40MHz
  parameter i2c_freq = 400000;   // 100k
  
  parameter clk_count4 = (sys_freq/i2c_freq)*4;   ///bit duration will have 400 clk pulses
  parameter clk_count1 = clk_count4/4;            /// single bit duration divided by 4 : 100 pulses
  
  integer count1 = 0;
  reg i2c_clk = 0;
  
  
  //////////////4x clock
  reg [1:0] pulse = 0;   // 4 pulses of a bit duration
  
  always@(posedge clk)begin
    if(rst) begin
      pulse <= 0;
      count1 <= 0;
    end
    else if(busy == 1'b0)begin
      pulse <= 0;
      count1 <= 0;
    end
    else if (count1 == clk_count1   -1)begin
      pulse <= 1;
      count1 <= count1 +1;
    end
    else if (count1 == clk_count1*2 -1)begin
      pulse <= 2;
      count1 <= count1 +1;
    end
    else if (count1 == clk_count1*3 -1)begin
      pulse <= 3; 
      count1 <= count1 +1;
    end
    else if (count1 == clk_count1*4 -1)begin
      pulse <= 0;
      count1 <= 0;
    end
    else begin
      count1 <= count1 +1;
    end
  end
  
  /////////////////
  
  reg [3:0] bitcount = 0;
  reg [7:0] data_addr = 0;
  reg [7:0] data_tx = 0;
  reg r_ack;
  reg[7:0] rx_data = 0;
  reg sda_en = 0;
  
  
  typedef enum bit[3:0] {
    idle       = 0,
    start      = 1,
    write_addr = 2,
    ack_1      = 3,
    write_data = 4,
    read_data  = 5,
    stop       = 6,
    ack_2      = 7,
    master_ack = 8
  } state_type;
  
  state_type state = idle;
  
  always@ (posedge clk)begin
    if(rst) begin
      bitcount  <= 0;
      data_addr <= 0;
      data_tx   <= 0;
      scl_t     <= 1;
      sda_t     <= 1;
      state     <= idle;
      busy      <= 1'b0;
      ack_err   <= 1'b0;
      done      <= 1'b0;
    end
    else begin
      case(state)
      ///////IDLE STATE
        idle: begin
          done <= 1'b0;
          if(newd == 1'b1) begin
            data_addr <= {addr,op};
            data_tx <= din;
            busy <= 1'b1;
            state <= start;
            ack_err <= 1'b0;
          end
          else begin
            data_addr <= 0;
            data_tx <= 0;
            busy <= 1'b0;
            state <= idle;
            ack_err <= 1'b0;
          end
        end
        
        ///////START STATE
        start: begin
          sda_en <= 1'b1;
          case(pulse)
            0: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            1: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
          endcase
          
          if(count1 == clk_count1*4-1)begin
            state <= write_addr;
            scl_t <= 1'b0;
          end
          else
            state <= start;
        end
        
        //////WRITE ADDR
        write_addr: begin
          sda_en <= 1'b1;  /// Master has control of the line
          if(bitcount <=7)begin
            case (pulse)
              0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_t <= data_addr[7-bitcount]; end
              2: begin scl_t <= 1'b1; end
              3: begin scl_t <= 1'b1; end
            endcase
            if(count1 == clk_count1*4 -1) begin
              state <= write_addr;
              scl_t <= 1'b0;
              bitcount <= bitcount +1;
            end
            else begin
              state <= write_addr;
            end
          end
          else begin
            state <= ack_1;
            bitcount <= 0; 
            sda_en <= 1'b0;  /// release the line into high impedence to receive ack from slave
          end
        end
        
        
        //////ACK1 from Slave
        ack_1 : begin
          sda_en <= 1'b0; /// release the line into high impedence to receive ack from slave
          case(pulse)
            0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= 1'b0;end //temporary
            3: begin scl_t <= 1'b1; end
          endcase
          if(count1 == clk_count1*4-1)begin
            if(r_ack == 1'b0 && data_addr[0] == 1'b0) begin  // write
              state <= write_data;
              sda_t <= 1'b0;
              sda_en <= 1'b1;  ///write data to slave
              bitcount <= 0;
            end
            else if (r_ack == 1'b0 && data_addr[0] == 1'b1)begin
              state <= read_data;
              sda_t <= 1'b1;
              sda_en <= 1'b0;  // release line to recv data
              bitcount <= 0;
            end
            else begin
              state <= stop; // wrong ack recv
              sda_en <= 1'b1;  // send stop to slave
              ack_err <= 1'b1;
            end
          end
          else begin
            state <= ack_1;
          end
        end
        
        /////// Write data
        write_data : begin
          if(bitcount <=7)begin
            case(pulse)  
              0: begin scl_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_en <= 1'b1; sda_t <= data_addr[7-bitcount]; end
              2: begin scl_t <= 1'b1; end
              3: begin scl_t <= 1'b1; end
            endcase
            if(count1 == clk_count1*4 -1) begin
              state <= write_data;
              scl_t <= 1'b0;
              bitcount <= bitcount +1;
            end
            else begin
              state <= write_data;
            end
          end
          else begin
            state <= ack_2;
            bitcount <= 0;
            sda_en <= 1'b0;   /// release line to read from slave
          end
        end
        
        ///////read_data
        
        read_data : begin
          sda_en <= 1'b0; /// read from slave
          if(bitcount <=7)begin
            case(pulse)
              0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
              2: begin scl_t <= 1'b1; rx_data[7:0] <= (count1 == 200) ?  {rx_data[6:0],sda} : rx_data; end //temporary
              3: begin scl_t <= 1'b1; end          
            endcase
            if(count1 == clk_count1*4 - 1)begin
              state <= read_data;
              scl_t <= 1'b0;
              bitcount <= bitcount +1;
            end
            else begin
              state <= read_data;
            end
          end
          else begin
            state <= master_ack;
            bitcount <= 0;
            sda_en <= 1'b1; ///Master takes control of line to send nack
          end
        end
        
        /////master ack
        
        master_ack : begin
          sda_en <= 1'b1;
          case(pulse) 
            0: begin scl_t <= 1'b0; sda_t <= 1'b1; end
            1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
            3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
          endcase
          
          if(count1 == clk_count1*4 -1) begin
            sda_t <= 1'b0;
            state <= stop;
            sda_en <= 1'b1;    // send stop to slave
          end
          else begin
            state <= master_ack;
          end
        end
          
            
        
        ///////ack_2
        
        ack_2 : begin
          sda_en <= 1'b0; /// release the line into high impedence to receive ack from slave
          case(pulse)
            0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= 1'b0;end //temporary
            3: begin scl_t <= 1'b1; end
          endcase
          if(count1 == clk_count1*4-1)begin
            sda_t <= 1'b0;
            sda_en <= 1'b1;  /// send stop to slave
            if(r_ack == 1'b0) begin  
              state <= stop;
              ack_err <= 1'b0;
            end
            else begin
              state <= stop; // wrong ack recv
              ack_err <= 1'b1;
            end
          end
          else begin
            state <= ack_2;
          end
        end 
        
        ////Stop
        
        stop : begin
          sda_en <= 1'b1;    /// send stop to slave
          case(pulse)
            0: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
            2: begin scl_t <= 1'b1; sda_t <= 1'b1; end //temporary
            3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
          endcase
          
          if(count1 == clk_count1*4 -1) begin
            state <= idle;
            scl_t <= 1'b0;
            busy <= 1'b0;
            done <= 1'b1;
          end
          else
            state <= stop;
        end
        
        default : state <= idle;
      endcase
    end
  end
  
  
  assign sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'b1 : 1'bz;
  
  //in a real scenario , to send 1, the master puts it to z and the pull up network sends 1
  //assign sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'bz : 1'bz;
  
  
  
  assign scl = scl_t;
  assign dout = rx_data;
endmodule
