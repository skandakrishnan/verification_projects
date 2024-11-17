// Code your testbench here
// or browse Examples
/*
ASSIGNMENT

Add two independent tasks in the driver: one to perform write operations on the FIFO until it becomes full, and another to read back all the data from the FIFO.

*/
class transaction;
  rand bit  oper;
  bit rd;
  bit wr;
  bit [7:0] data_in;
  bit full;
  bit empty;
  bit [7:0] data_out;
  
  constraint oper_ctrl{
    oper dist {1:/50 , 0:/50};
  }
endclass




class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  int count = 0;
  int i = 0;
  event next;   ///know when to send next transaction
  event done;   ///conveys completion of requested no. of transaction
  

  
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
  
  task run_assign();
    repeat(count)
      begin
        if(i < (count/2))
          tr.oper = 1'b1;
        else
          tr.oper = 1'b0;
        i++;
        mbx.put(tr);
        $display("[GEN] : Oper : %0b Iteration : %0d" , tr.oper, i);
        @(next);
      end
    
    ->done;
  endtask
  
  
endclass

class driver;
  
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction datac;
  
  
  
    
  function new(
    input mailbox #(transaction) mbx
  );    
    this.mbx = mbx;
  endfunction;
    
    
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
    
  
  task write();  
    @(posedge fif.clock);    
    fif.rst <= 1'b0;    
    fif.rd <= 1'b0;    
    fif.wr <= 1'b1;    
    fif.data_in <= $urandom_range(1,10);        
    @(posedge fif.clock);    
    fif.wr <= 1'b0;    
    $display("[DRV] : DATA WRITE data : 0%d", fif.data_in);    
    @(posedge fif.clock);    
  endtask
    
    
    
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
    
  
  
  task run();  
    forever begin    
      mbx.get(datac);      
      if(datac.oper == 1'b1)      
        write();        
      else      
        read();     
    end    
  endtask
    
      
endclass
    
    
class monitor;
  virtual fifo_if fif;
  mailbox #(transaction) mbx;
  transaction tr;
  
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
  mailbox #(transaction) mbx;
  transaction tr;
  event next;
  
  bit [7:0] din[$];   //queue
  bit [7:0] temp;
  int err = 0;
  
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
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
    
  endtask
  
  task test_assign();
    fork
      gen.run_assign();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  

    
  
  task post_test();
    wait(gen.done.triggered);
    $display("------------------------------------------");
    $display("ERROR COUNT : %0d", sco.err);
    $display("------------------------------------------");
    $finish();

  endtask
  
  
  task run();
    pre_test();
    test_assign();
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
    env.gen.count = 40;
    env.run();
    
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
   
  end
  
endmodule
