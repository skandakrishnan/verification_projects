// Code your testbench here
// or browse Examples



//APB Memory TB

//Use Design File : uart_rxtx.sv

class transaction;
  
  randc bit op;
  randc bit [31:0] awaddr;
  rand bit [31:0] wdata;
  randc bit [31:0] araddr;
  bit [31:0] rdata;
  bit [1:0] wresp;
  bit [1:0] rresp;
  
  constraint valid_addr_range { 
    awaddr <50; 
    araddr <50;
  }
  constraint valid_data_range { 
    wdata < 100; 
    rdata < 100;
  }
  
endclass
            




class generator ;
  transaction tr;
  mailbox #(transaction) mbxgd;
  event done;
  
  //event nextdrv ;  ///driver completed task of triggering interface
  event sconext ;  ///scoreboard completed its objective
  
  int count = 0;
  
  function new(mailbox #(transaction) mbxgd);
    this.mbxgd = mbxgd;
    tr = new();
  endfunction
  
  task run();
    repeat(count)begin
      assert(tr.randomize) else $error("[GEN]: Randomization Failed");
      //tr.op = 1'b1;
      mbxgd.put(tr);
      //tr.display("GEN");
      if(tr.op == 1'b1)
        $display("[GEN] : Oper : WRITE, awaddr : %0d,  wdata : %0d", tr.awaddr, tr.wdata);
      else
        $display("[GEN] : Oper : READ, araddr : %0d", tr.araddr);

      @(sconext);
    end
    ->done;
  endtask
endclass

class driver; 
  virtual axi_if vif;
  transaction tr;
  
  mailbox #(transaction) mbxgd;
  mailbox #(transaction) mbxdm;
  
  
  event nextdrv;


  
  function new (
    input mailbox #(transaction) mbxgd,
    input mailbox #(transaction) mbxdm
  );
    this.mbxgd = mbxgd;
    this.mbxdm = mbxdm;
  endfunction
  
  task reset ();
    
    vif.resetn <= 1'b0;
    vif.awvalid <= 1'b0;
    vif.awaddr <= 0;
    vif.wvalid <= 0;
    vif.wdata <= 0;
    vif.bready <= 0;
    vif.arvalid <= 1'b0;
    vif.araddr <= 0;
    repeat(5) @(posedge vif.clk);
    vif.resetn <= 1'b1;
    $display("[DRV] : RESET DONE");
    $display("-----------------------------------------------");
  endtask
  
  task write_data(input transaction tr);
    $display("[DRV] : Oper : WRITE, awaddr : %0d,  wdata : %0d", tr.awaddr, tr.wdata);
    mbxdm.put(tr);
    vif.resetn <= 1'b1;
    vif.awvalid <= 1'b1;
    vif.arvalid <= 1'b0; //disable read
    vif.araddr <= 0;
    vif.awaddr <= tr.awaddr;
    @(negedge vif.awready);
    vif.awvalid <= 1'b0;
    vif.awaddr <= 0;
    vif.wvalid <= 1'b1;
    vif.wdata <= tr.wdata;
   // $display("[DRV] : Oper : WRITE, awaddr : %0d,  wdata : %0d", tr.awaddr, tr.wdata);
    @(negedge vif.wready);
    vif.wvalid <= 1'b0;
    vif.wdata <= 0;
    vif.bready <= 1'b1;
    vif.rready <= 1'b0;
    //$display("[DRV] : Oper : WRITE, awaddr : %0d,  wdata : %0d", tr.awaddr, tr.wdata);
    @(negedge vif.bvalid);
    vif.bready <= 1'b0;
    //$display("[DRV] : Oper : WRITE, awaddr : %0d,  wdata : %0d", tr.awaddr, tr.wdata);
  endtask
  
  task read_data(input transaction tr);
    $display("[DRV] : Oper : READ, araddr : %0d", tr.araddr);
    mbxdm.put(tr);
    vif.resetn <= 1'b1;
    vif.awvalid <= 1'b0;  //disable write
    vif.awaddr <= 0;
    vif.wvalid <= 1'b0;
    vif.wdata <= 0;
    vif.bready <= 1'b1;
    vif.arvalid <= 1'b1; 
    vif.araddr <= tr.araddr;
    @(negedge vif.arready);
    //$display("[DRV] : Oper : READ, araddr : %0d", tr.araddr);
    vif.araddr <= 0;
    vif.arvalid <= 1'b0;
    vif.rready <= 1'b1;
    @(negedge vif.rvalid);
    vif.rready <= 1'b0;
  endtask
  
  task run();
    forever begin
      mbxgd.get(tr);
      @(posedge vif.clk);
      if(tr.op == 1'b1)
        write_data(tr);
      else
        read_data(tr);
    end
  endtask
  
endclass








class monitor;
  transaction tr, trd;
  mailbox #(transaction) mbxms;
  mailbox #(transaction) mbxdm;
  

  virtual axi_if vif;
  
  function new(
    input mailbox #(transaction) mbxms,
    input mailbox #(transaction) mbxdm
  );
    this.mbxms = mbxms;
    this.mbxdm = mbxdm;
  endfunction
  
  
  task run();
    tr = new();
    forever begin
      @(posedge vif.clk);
      mbxdm.get(trd);
      if(trd.op ==1) begin
        tr.op = trd.op;
        tr.awaddr = trd.awaddr;
        tr.wdata = trd.wdata;
		//$display("[MON] : Oper 1");
        
        //#1000;
        //$finish();
        @(posedge vif.bvalid);
        tr.wresp = vif.wresp;
		
        @(negedge vif.bvalid);
        $display("[MON] : Oper : WRITE, awaddr : %0d,  wdata : %0d, wresp: %0b", tr.awaddr, tr.wdata, tr.wresp);
         mbxms.put(tr);  
      end
      else begin
        tr.op = trd.op;
        tr.araddr = trd.araddr;
        @(posedge vif.rvalid);
        tr.rdata = vif.rdata;
        tr.rresp = vif.rresp;
        @(negedge vif.rvalid);        
        $display("[MON] : Oper : READ, araddr : %0d, rdata : %0d, rresp : %0b", tr.araddr, tr.rdata, tr.rresp);
        mbxms.put(tr);
      end
    end
  endtask

endclass

class scoreboard;
  transaction tr,trd;
  

  mailbox #(transaction) mbxms;
  
  

  int err = 0;
  event sconext;
  int err_ack = 0;
  bit [31:0] temp;
  bit [31:0] data [128] = '{default:0};
  
  function new(
    input mailbox #(transaction) mbxms
  );
    this.mbxms = mbxms;
  endfunction
  
  task run();
    forever begin

      mbxms.get(tr);
      
      
      if( tr.op == 1 )begin
        $display("[SCO] : Oper : WRITE, awaddr : %0d,  wdata : %0d, wresp: %0b", tr.awaddr, tr.wdata, tr.wresp);
        if(tr.wresp == 3) begin
          $display("[SCO] : DEC ERROR");
          err++;
        end          
        else begin
          data [tr.awaddr] = tr.wdata;
          $display("[SCO] : DATA STORED ADDR : %0d, DATA : %0d", tr.awaddr, tr.wdata);
        end
        $display ("------------------------------------------------------");
      end
      
      else begin 
        $display("[SCO] : Oper : READ, araddr : %0d, rdata : %0d, rresp : %0b", tr.araddr, tr.rdata, tr.rresp);
        temp = data[tr.araddr];
        if(tr.rresp == 3) begin
          $display("[SCO] : DEC ERROR");
          err++;
        end          
        else begin
          if(temp == tr.rdata)
            $display("[SCO] : DATA MATCHED");
          else begin
            $display("[SCO] : DATA MISMATCHED");
            err++;
          end            
        end
        $display ("------------------------------------------------------");
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
  event nextgm;
  
  mailbox #(transaction) mbxgd;

  mailbox #(transaction) mbxms;
  mailbox #(transaction) mbxdm;
  
  virtual axi_if vif;
  
  function new( input virtual axi_if vif);
    mbxgd = new();
    mbxms = new();
    mbxdm = new();
    
    gen = new(mbxgd);
    drv = new(mbxgd,mbxdm);
    
    mon = new(mbxms,mbxdm);
    sco = new(mbxms);
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
   // sco.vif = this.vif;
    
    gen.sconext = nextgm;
    sco.sconext = nextgm;
    
  
    
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
    $display("Number of ERROR : %0d", sco.err);

    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass


module tb;
  axi_if vif();
  
  axilite_s dut (
    .s_axi_aclk    (vif.clk),
    .s_axi_aresetn (vif.resetn),
    .s_axi_awvalid (vif.awvalid),
    .s_axi_awready (vif.awready),
    .s_axi_awaddr  (vif.awaddr),
    .s_axi_wvalid  (vif.wvalid),
    .s_axi_wready  (vif.wready),
    .s_axi_wdata   (vif.wdata),
    .s_axi_bvalid  (vif.bvalid),
    .s_axi_bready  (vif.bready),
    .s_axi_bresp   (vif.wresp),
    .s_axi_arvalid (vif.arvalid),   
    .s_axi_arready (vif.arready),
    .s_axi_araddr  (vif.araddr),
    .s_axi_rvalid  (vif.rvalid),
    .s_axi_rready  (vif.rready),
    .s_axi_rdata   (vif.rdata),
    .s_axi_rresp   (vif.rresp)
  );
  
  initial begin 
    vif.clk <= 0;
  end
  always #10 vif.clk <= ~vif.clk;
 
  environment env;
  
  initial begin
    env = new(vif);
    env.gen.count =100;
    env.run();
  end
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  

endmodule
  
  
  

