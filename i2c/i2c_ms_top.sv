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
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda;end //temporary
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
              1: begin scl_t <= 1'b0; sda_en <= 1'b1; sda_t <= data_tx[7-bitcount]; end
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
            2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= sda;end 
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

module i2c_slave(
  input scl,
  input clk,
  input rst,
  inout sda,
  output reg ack_err,
  output reg done
);  
  
  typedef enum bit[3:0] {
    idle        = 0,
    read_addr   = 1,
    send_ack1   = 2,
    send_data   = 3,
    master_ack  = 4,
    read_data   = 5,
    send_ack2   = 6,
    wait_p      = 7,
    detect_stop = 8
  } state_type;
  
  state_type state = idle;
  
  
  reg [7:0] mem[128];
  reg [7:0] r_addr;
  reg [6:0] addr;
  reg r_mem = 0;
  reg w_mem = 0;
  reg [7:0] dout;
  reg [7:0] din;
  reg sda_t;
  reg sda_en;
  reg [3:0] bitcnt = 0;
  
  //initialize mem and rd and wr into mem
  always @(posedge clk) begin
    if(rst) begin
      for(int i = 0; i<128; i++)begin
        mem[i] = i;
      end
      dout <= 8'd0;
    end
    else if (r_mem ==1'b1)begin
      dout <= mem[addr];
    end
    else if (w_mem == 1'b1)begin
      mem[addr] <= din;
    end
  end
  
  

  parameter sys_freq = 40000000; //40MHz
  parameter i2c_freq = 400000;   // 100k
  
  parameter clk_count4 = (sys_freq/i2c_freq)*4;   ///bit duration will have 400 clk pulses
  parameter clk_count1 = clk_count4/4;            /// single bit duration divided by 4 : 100 pulses
  
  integer count1 = 0;
  reg i2c_clk = 0;
  
  
  //////////////4x clock
  reg [1:0] pulse = 0;   // 4 pulses of a bit duration
  reg busy;
  
  always@(posedge clk)begin
    if(rst) begin
      pulse <= 0;
      count1 <= 0;
    end
    else if(busy == 1'b0)begin
      pulse <= 2;
      count1 <= 202;             // to make sure master and slave are sync
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
  
  reg scl_t;
  wire start;
  
  always @(posedge clk) begin
    scl_t <= scl;
  end
  
  assign start = ~scl & scl_t;
  
  reg r_ack;
  
  always @(posedge clk) begin
    if(rst) begin
      bitcnt <= 0;
      state <= idle;
      r_addr <= 7'd0;
      sda_en <= 1'b0;
      sda_t <= 1'b0;
      addr <= 0;
      r_mem <= 0;
      din <= 8'd0;
      ack_err <= 0;
      done <= 1'b0;
      busy <= 1'b0;
    end
    else begin
      case(state)
        
        ////IDLE
        idle : begin
          if(scl == 1'b1 && sda == 1'b0) begin
            busy <= 1'b1;
            state <= wait_p;
          end
          else begin
            state <= idle ;
          end
        end
        
        
        //////wait for pulse
        wait_p : begin
          if (pulse == 2'b11 && count1 == 399)
            state <= read_addr;
          else
            state <= wait_p;
        end
        
        ////read_addr
        read_addr : begin
          sda_en <= 1'b0;
          if(bitcnt <=7) begin
            case(pulse)
              0: begin end
              1: begin end
              2: begin r_addr <= (count1 == 200)? {r_addr[6:0],sda}: r_addr;end
              3: begin end
            endcase
            if(count1 == clk_count1*4 - 1)begin
              state <= read_addr;
              bitcnt <= bitcnt +1;
            end
            else begin
              state <= read_addr;
            end
          end
          else begin
            state <= send_ack1;
            bitcnt <= 0;
            sda_en <= 1'b1;
            addr <= r_addr [7:1];
          end
        end
        
        /////send ack
        send_ack1 : begin
          case(pulse)
            0: begin sda_t <= 1'b0; end
            1: begin end
            2: begin end
            3: begin end
          endcase
          if(count1 == clk_count1*4 -1) begin
            if(r_addr[0] == 1'b1) begin
              state <= send_data;
              r_mem <= 1'b1;
            end
            else begin
              state <= read_data;
              r_mem <= 1'b0;
            end
          end
          else begin
            state <= send_ack1;
          end
        end
        
        /// read data
        read_data : begin
          sda_en <= 1'b0; /// release line to master
          if(bitcnt <= 7) begin
            case(pulse)
              0: begin end
              1: begin end
              2: begin din <= (count1==200) ? {din[6:0],sda} : din; end
              3: begin end
            endcase
            if(count1 == clk_count1*4 - 1)begin
              state <= read_data;
              bitcnt <= bitcnt +1;
            end
            else begin             
              state <= read_data;
            end
          end
          else begin
            state <= send_ack2;
            bitcnt <= 0;
            sda_en <= 1'b1;
            w_mem <= 1'b1;
          end
        end
        
        /////send sck2
        send_ack2: begin       
          case(pulse)
            0: begin sda_t <= 1'b0; end
            1: begin w_mem <= 1'b0; end
            2: begin end
            3: begin end
          endcase
          if(count1 == clk_count1*4-1)begin
            state <= detect_stop;
            sda_en <= 1'b0;
          end
          else begin
            state <= send_ack2;
          end
        end
        
        ////send_data
        send_data: begin
          sda_en <= 1'b1;   ///take control of line to send data
          if(bitcnt <= 7) begin
            r_mem <= 1'b0;
            case(pulse)
              0: begin end
              1: begin sda_t <= (count1 == 100) ? dout[7-bitcnt] : sda_t; end
              2: begin end
              3: begin end
            endcase
            if(count1 == clk_count1*4 -1)begin
              state <= send_data;
              bitcnt <= bitcnt +1;
            end
            else begin
              state <= send_data;
            end
          end
          else begin
            state <= master_ack;
            bitcnt <= 0;
            sda_en <= 1'b0;
          end
        end
        
        master_ack: begin
          case(pulse) 
            0: begin end
            1: begin end
            2: begin r_ack <= (count1 == 200) ? sda : r_ack; end
            3: begin end
          endcase
          if(count1 == clk_count1*4 - 1)begin
            if(r_ack == 1'b1) begin////nack
              ack_err <= 1'b0;
              state <= detect_stop;
            end
            else begin
              ack_err <= 1'b1;
              state <= detect_stop;
            end
          end
          else begin 
            state <= master_ack;
          end
        end
           
        detect_stop: begin
          if(pulse == 2'b11 && count1 == 399)begin
            state <= idle;
            busy <= 1'b0;
            done <= 1'b1;
          end
          else
            state <= detect_stop;
        end
        
        default : state <= idle;
      endcase
    end
  end
  
  assign sda = (sda_en == 1'b1) ? sda_t : 1'bz;
            
            
              
              
            
          
endmodule


module i2c_top(
  input clk,
  input rst,
  input newd,
  input op,
  input [6:0] addr,
  input [7:0] din,
  output [7:0] dout,
  output busy,
  output ack_err,
  output done
);
  wire sda, scl;
  wire ack_errm, ack_errs;
  
  i2c_master master(
    .clk     (clk),
    .rst     (rst),
    .newd    (newd),
    .addr    (addr),
    .op      (op),
    .sda     (sda),
    .scl     (scl),
    .din     (din),
    .dout    (dout),
    .busy    (busy),
    .ack_err (ack_errm),
    .done    (done)
  );
  
  i2c_slave slave(
    .scl     (scl),
    .clk     (clk),
    .rst     (rst),
    .sda     (sda),
    .ack_err (ack_errs),
    .done    (done)
  );
   
  assign ack_err = ack_errs | ack_errm;   
  
endmodule
        
          
interface i2c_if;
  logic clk;
  logic rst;
  logic newd;
  logic op;
  logic [7:0] din;
  logic [6:0] addr;
  logic [7:0] dout;
  logic done;
  logic busy;
  logic ack_err;
endinterface
            
        
              
        
        
              
              
              
            
          
        
            
          
      
      
      
      
    
      
      
  

          
  
  
        
  
  