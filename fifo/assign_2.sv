// Code your testbench here
// or browse Examples

/*
ASSIGNMENT

Add two independent tasks in the driver: one to perform write operations on the FIFO until it becomes full, and another to read back all the data from the FIFO.

*/


class transaction;
  rand bit oper;               // Randomized bit for operation control (1 or 0)
  bit rd;                      // Read and Write control bits
  bit wr;           
  bit [7:0] data_in;           // 8-bit data input
  bit full;                    // Flags for full and empty status
  bit empty;
  bit [7:0] data_out;          // 8-bit data output
  
  constraint oper_ctrl{
    oper dist {1:/50 , 0:/50}; // Constraint to randomize 'oper' with 50% probability of 1 and 50% probability of 0 
  }
endclass


////////////////////////////////////////////////////////////////

class generator;
  transaction tr;              // Transaction object to generate and send 
  mailbox #(transaction) mbx;  // Mailbox for communication
  int count = 0;               // Number of Transactions to generate
  int i = 0;                   // Iteration Counter
  event next;                  // know when to send next transaction
  event done;                  // conveys completion of requested no. of transaction
  
  function new(
    input mailbox #(transaction) mbx
  );
    this.mbx = mbx;
    tr = new();
  endfunction;
  
  task run();
    repeat(count)
      begin
        assert(tr.randomize) else $error("Randomization failed");
        i++;
        mbx.put(tr);
        $display("[GEN] : Oper : %0b Iteration : %0d" , tr.oper, i);
        @(next);
      end
    
    ->done;
  endtask
  
  
endclass

class driver;
  
  virtual fifo_if fif;          // Virtual interface to the FIFO
  mailbox #(transaction) mbx;   // Mailbox for communication
  transaction datac;            // Transaction object for communication
  event done;
  
  
    
  function new(
    input mailbox #(transaction) mbx
  );    
    this.mbx = mbx;
  endfunction;
    
  //RESET the DUT  
  task reset();
    fif.rst <= 1'b1;
    fif.rd <= 1'b0;
    fif.wr <= 1'b0;
    fif.data_in <= 0;
    repeat(5) @(posedge fif.clock);    
    fif.rst <= 1'b0;    
    $display("[DRV] : DUT Reset DONE");    
    $display("-----------------------------------------");   
  endtask
    
  // Write data into the FIFO
  task write();  
    @(posedge fif.clock);    
    fif.rst <= 1'b0;    
    fif.rd <= 1'b0;    
    fif.wr <= 1'b1;    
    fif.data_in <= $urandom_range(1,15);        
    @(posedge fif.clock);    
    fif.wr <= 1'b0;    
    $display("[DRV] : DATA WRITE data : 0%d", fif.data_in);    
    @(posedge fif.clock);    
  endtask
    
    
  // Read data from the FIFO  
  task read(); 
    @(posedge fif.clock);    
    fif.rst <= 1'b0;    
    fif.rd <= 1'b1;    
    fif.wr <= 1'b0;    
    @(posedge fif.clock);    
    fif.rd <= 1'b0;    
    $display("[DRV] : DATA READ");    
    @(posedge fif.clock);    
  endtask
    
  
  task write_till_full();
    while(fif.full == 1'b0)
      write();
  endtask
  
  task read_till_empty();
    while(fif.empty == 1'b0)
      read();
  endtask
  //Apply random stimulus to the DUT
  task run();             
    write_till_full();    
    write();      
    $display("[DRV] : FULL TRIGGERRED");      
    read_till_empty();      
    read();
    $display("[DRV] : EMPTY TRIGGERRED");
    read();
         
    ->done;          
  endtask
    
      
endclass
    
    
class monitor;
  virtual fifo_if fif;            // Virtual interface to the FIFO
  mailbox #(transaction) mbx;     // Mailbox for communication
  transaction tr;                 // Transaction object for monitoring
  
  function new (input mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction;
  
  task run();
    tr = new();
    forever begin 
      repeat(2) @(posedge fif.clock);
      tr.wr = fif.wr;
      tr.rd = fif.rd;
      tr.data_in = fif.data_in;
      tr.full = fif.full;
      tr.empty = fif.empty;
      @(posedge fif.clock);
      tr.data_out = fif.data_out;
      mbx.put(tr);
      
      $display("[MON] : wr:%0b rd:%0b din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);            
    end    
  endtask
  
  
endclass


class scoreboard;
  mailbox #(transaction) mbx;        // Mailbox for communication
  transaction tr;                    // Transaction object for monitoring
  event next;
  
  bit [7:0] din[$];   //queue        // Array to store written data
  bit [7:0] temp;                    // Temporary data storage
  int err = 0;                       // Error Count
  
  function new(
    input mailbox #(transaction) mbx
  );
    this.mbx = mbx;
  endfunction;
  
  task run();
    forever begin
      mbx.get(tr);
      $display("[SCO] : wr:%0b rd:%0b din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.data_in, tr.data_out, tr.full, tr.empty);
      
      if(tr.wr ==1'b1)
        begin
          if(tr.full == 1'b0)
            begin 
              din.push_front(tr.data_in);
              $display("[SCO] : DATA STORED in QUEUE : %0d", tr.data_in);
            end
          else
            begin
              $display("[SCO] : FIFO is FULL");
            end
          $display("--------------------------------");
        end
              
      if(tr.rd == 1'b1)
        begin
          if(tr.empty == 1'b0)
            begin
              temp = din.pop_back();
              if(tr.data_out == temp)
                $display("[SCO] : DATA MATCH");
              else begin
                $error("[SCO] : DATA MISMATCH @ time : %0t", $time);
                err++;
              end
            end    
          else begin    
            $display("[SCO] : FIFO EMPTY");
          end
          $display ("-------------------------------");
        end
      
      ->next;
      
    end
  endtask
endclass


class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  mailbox #(transaction) gdmbx;  ///gen -> drv
  mailbox #(transaction) msmbx;  ///mon -> sco
  
  event nextgs;
  
  
  virtual fifo_if fif;
  
  function new(input virtual fifo_if fif);
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    
    this.fif = fif;
    drv.fif = this.fif;
    mon.fif = this.fif;
    
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test ();
    fork
    //  gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
    
  endtask
  
  task post_test();
    wait(drv.done.triggered);
    $display("------------------------------------------");
    $display("ERROR COUNT : %0d", sco.err);
    $display("------------------------------------------");
    
    $finish();
  endtask
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass


module tb;
  fifo_if fif();
  
  FIFO dut (
    .clk(fif.clock),
    .rst(fif.rst),
    .wr(fif.wr),
    .rd(fif.rd),
    .din(fif.data_in),
    .empty(fif.empty),
    .full(fif.full),
    .dout(fif.data_out)
  );
  
  initial begin
    fif.clock <= 0;
  end
  
  always #10 fif.clock <= ~fif.clock;
  
  environment env;
  
  initial begin
    env = new(fif);
    env.gen.count = 10;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule
