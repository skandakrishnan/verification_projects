The readme.txt gives the commands needed to run the iverilog testbench for the tpu and its subunits.
Make sure all the following files are in the same folder before running(tb_mac.v mac.v tb_quant.v quant.v tb_activ.v activ.v tb_tpu_top.v tpu_top.v)  


For running the tb for mac:

Enter : 
iverilog tb_mac.v mac.v
vvp a.out


For running the tb for activation unit:

Enter : 
iverilog tb_activ.v activ.v
vvp a.out


For Running the tb for the quantization unit: 

Enter : 
iverilog tb_quant.v quant.v
vvp a.out


For Running the tb for the tpu unit

Enter : 
iverilog tb_tpu_top.v tpu_top.v quant.v mac.v activ.v
vvp a.out
