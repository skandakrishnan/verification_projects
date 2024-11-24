// Code your testbench here
// or browse Examples



//UART Top contains independent RX and TX. 

//Use Design File : i2c_ms_top.sv

class transaction;

  bit newd;
  rand bit op;
  rand bit [7:0] din;
  rand bit [6:0] addr;
  bit [7:0] dout;
  bit done;
  bit busy;
  bit ack_err;
  
 // constraint addr_c { 
 //   addr > 1 ; addr < 5 ;
 //   din  > 1 ; din  < 10;
//  }
  
  constraint rd_wr_c {
    op dist { 1:/50 , 0 :/50 };
  }
endclass



class generator ;
  transaction tr;
  mailbox #(transaction) mbxgd;
  event done;
  
  event drvnext ;
  event sconext ;
  
  int count = 0;
  
  function new(mailbox #(transaction) mbxgd);
    this.mbxgd = mbxgd;
    tr = new();
  endfunction
  
  task run();
    repeat(count)begin
      assert(tr.randomize) else $error("[GEN]: Randomization Failed");
      mbxgd.put(tr);
      $display("[GEN] : Oper : %0d, addr : %0d,  Din : %0d", tr.op, tr.addr, tr.din);
      @(drvnext);
      @(sconext);
    end
    ->done;
  endtask
endclass

class driver; 
  virtual i2c_if vif;
  transaction tr;
  
  mailbox #(transaction) mbxgd;
  
  
  event drvnext;


  
  function new (
    input mailbox #(transaction) mbxgd
  );
    this.mbxgd = mbxgd;
  endfunction
  
  task reset ();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.op <= 1'b0;
    vif.din <= 0;
    vif.addr <= 0;
    repeat(10) @(posedge vif.clk);
    vif.rst <= 1'b0;
    $display("[DRV] : RESET DONE");
    $display("-----------------------------------------------");
  endtask
  
  task write();
    vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b0;
    vif.din <= tr.din;
    vif.addr <= tr.addr;
    repeat(5) @(posedge vif.clk);
    vif.newd <= 1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP : WR, ADDR : %0d, DIN : %0d", tr.addr, tr.din);
    vif.newd <= 1'b0;
  endtask
  
  task read();
    vif.rst <= 1'b0;
    vif.newd <= 1'b1;
    vif.op <= 1'b1;
    vif.din <= 0;
    vif.addr <= tr.addr;
    repeat(5) @(posedge vif.clk);
    vif.newd <= 1'b0;
    @(posedge vif.done);
    $display("[DRV] : OP : RD, DOUT : %0d", tr.addr,vif.dout);
  endtask

    
  
  task run();
    forever begin
      mbxgd.get(tr);
      
      if(tr.op == 1'b0)
        write();
      else
        read();
      ->drvnext;  
    end
  endtask
  
  
endclass



class monitor;
  transaction tr;
  mailbox #(transaction) mbxms;
  

  virtual i2c_if vif;
  
  function new(
    input mailbox #(transaction) mbxms);
    this.mbxms = mbxms;
  endfunction
  
  
  task run();
    tr = new();
    forever begin
      @(posedge vif.done);
      tr.din = vif.din;
      tr.addr = vif.addr;
      tr.op = vif.op;
      tr.dout = vif.dout;
      repeat(5) @(posedge vif.clk);
      mbxms.put(tr);
      $display("[MON] op: %0d, addr: %0d, din : %0d, dout: %0d", tr.op, tr.addr, tr.din, tr.dout);
    end
  endtask
  
endclass

class scoreboard;
  transaction tr;

  mailbox #(transaction) mbxms;
  

  int err = 0;
  event sconext;
  
  bit [7:0] temp;
  bit [7:0] mem [128] = '{default:0};
  
  function new(
    input mailbox #(transaction) mbxms
  );
    this.mbxms = mbxms;
    for(int i = 0; i< 128; i++) begin
      mem[i] <= i;
    end  
  endfunction
  
  task run();
    forever begin

      mbxms.get(tr);
      temp = mem[tr.addr];

      if(tr.op == 1'b0)begin // write
        mem[tr.addr] = tr.din;
        $display("[SCO]: DATA STORED at SLAVE-> ADDR : %0d DATA : %0d", tr.addr, tr.din);
        $display("----------------------------------------------------------------");
      end
      else begin
        if( (tr.dout == temp) )
          $display("[SCO]: DATA READ -> Data Matched exp: %0d rec: %0d", temp,tr.dout);
        else begin
          $display("[SCO]: DATA READ -> Data MISMATCHED exp: %0d rec: %0d", temp,tr.dout);
          err++;
        end
        
        $display("----------------------------------------------------------------");
      end
      ->sconext;
    end
  endtask
      
endclass


class environment ;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event nextgd;
  event nextgs;
  
  mailbox #(transaction) mbxgd;

  mailbox #(transaction) mbxms;
  
  virtual i2c_if vif;
  
  function new( input virtual i2c_if vif);
    mbxgd = new();
    mbxms = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd);
    
    mon = new(mbxms);
    sco = new(mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
   // sco.vif = this.vif;
    
    gen.sconext = nextgs;
    sco.sconext = nextgs;
    
    gen.drvnext = nextgd;
    drv.drvnext = nextgd;
    
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      sco.run();
      mon.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $display("Number of DATA MISMATCH : %0d", sco.err);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass


module tb;
  i2c_if vif();
  
  i2c_top dut (
    .clk(vif.clk),
    .rst(vif.rst),
    .op(vif.op),
    .addr(vif.addr),
    .newd(vif.newd),
    .din(vif.din),
    .dout(vif.dout),
    .busy(vif.busy),
    .done(vif.done),
    .ack_err(vif.ack_err)
  );
  
  initial begin 
    vif.clk <= 0;
  end
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count = 100;
    env.run();
  end
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  

endmodule
  
    
    
  

  
        
        
          
  
        
                 
      
    
    
  

  
  
  
  
  
  





      



