// Code your testbench here
// or browse Examples

class transaction;
  
  rand logic din;
  logic dout;
  function transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] : DIN : %0b , DOUT : %0b", tag,din,dout);
  endfunction
endclass


//////////////////////////////////////////////////////////////////////
class generator;
  
  transaction tr;
  mailbox #(transaction) mbx;    /// send data to driver
  mailbox #(transaction) mbxref; /// send data to scoreboard;
  
  event sconext;                 /// sense completion of scoreboard work
  event done;                    /// trigger once requested number of stimui
  int count;                     /// stimulus count
  
  function new ( 
    input mailbox #(transaction) mbx, 
    input mailbox #(transaction) mbxref
  );
    this.mbx = mbx;
    this.mbxref = mbxref;
    tr = new();
  endfunction
  
  task run();
    //tr.din = 1'bx;
    repeat(count) begin
      assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
      //tr.din = ~tr.din;
      //tr.din = 1'bx;
      mbx.put(tr.copy);
      mbxref.put(tr.copy);
      $display("[GEN] : DATA SENT TO [DRV] AND [SCO]");
      tr.display("GEN");
      @(sconext);
    end
    ->done;
  endtask
  
endclass

////////////////////////////////////////////////////////////////////////////////
class driver;
  
  transaction tr;
  mailbox #(transaction) mbx;    /// rcv data from generator
  virtual dff_if vif;
  
  function new(
    input mailbox #(transaction) mbx
  );
    this.mbx = mbx;
  endfunction
  
  task reset();
    vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 1'b0;
    @(posedge vif.clk);
    $display("[DRV] : RESET DONE");
  endtask
  
  task run();
    forever begin
      mbx.get(tr);
      $display("[DRV] : DATA RCVD FROM [GEN]");
      vif.din <= tr.din;
      @(posedge vif.clk);
      tr.display("DRV");
      vif.din <= 1'b0;
      @(posedge vif.clk);
    end
  endtask
endclass

///////////////////////////////////////////////////////////////////////////////
class monitor;
  
  transaction tr;
  mailbox #(transaction) mbx;
  virtual dff_if vif;
  
  function new( 
    input mailbox #(transaction) mbx
  );
  
    this.mbx = mbx;
  endfunction
  
  task run();
    tr = new();
    forever begin
      repeat(2) @(posedge vif.clk);
      tr.dout = vif.dout;
      mbx.put(tr);
      $display("[MON] : DATA READ AND SENT TO [SCO]");
      tr.display("MON");
    end
  endtask
  
  
endclass


////////////////////////////////////////////////////////////////////////////
class scoreboard;
  
  transaction tr;
  transaction trref;
  mailbox #(transaction) mbx;
  mailbox #(transaction) mbxref;
  event sconext;
  
  function new(
    input mailbox #(transaction) mbx,
    input mailbox #(transaction) mbxref
  );
    this.mbx = mbx;
    this.mbxref = mbxref;
  endfunction
  
  task run();
    forever begin
      mbxref.get(trref);
      $display("[SCO] : REFERENCE RCVD FROM [GEN]");
      trref.display("REF");
      
      mbx.get(tr);
      $display("[SCO] : DATA RCVD FROM [MON]");      
      tr.display("SCO");
      
      if((tr.dout == trref.din) || ( (trref.din === 1'bx) && (!tr.dout) ))
        $display("[SCO] : DATA MATCHED");
      else
        $display("[SCO] : DATA MISMATCHED");
      $display("------------------------------------------------");
      ->sconext;
    end
      
  endtask
endclass
  
  
                 
/////////////////////////////////////////////////////////////////

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  event next;    ////gen -> sco
  
  
  mailbox #(transaction) gdmbx;  /// gen -> drv
  mailbox #(transaction) msmbx;  /// mon -> sco
  mailbox #(transaction) mbxref; /// gen -> sco
  
  virtual dff_if vif;
  
  function new(virtual dff_if vif);
    gdmbx = new();
    mbxref = new();
    
    gen = new(gdmbx, mbxref);
    drv = new(gdmbx);
    
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx, mbxref);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    
    gen.sconext = next;
    sco.sconext = next;
    
  endfunction
  
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
  dff_if vif();
  dff dut(vif);
  
  
  initial begin
    vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk;
  
  environment env;
  
  
  initial begin
    env = new(vif);
    env.gen.count = 30;
    env.run();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
endmodule
  
  
  
    
  


