//--------------------------------------
//Project:  JTAG programming
//Function: JTAG TOP module
//Authors:  Nguyen Hung Quan
//Page:     VLSI Technology
//Website:  http://nguyenquanicd.blogspot.com/
//--------------------------------------
module jtag_top (
  //JTAG interface
  input TCK,
  input jtag_rst_n,
  input TMS,
  input TDI,
  output logic TDO,
  //Memory controller interface
  input clk,
  input sys_rst_n
  );
  //
  logic ready;
  logic [15:0] rdata;
  logic sel;
  logic we;
  logic [7:0] addr;
  logic [15:0] wdata;
  logic mem_sel;
  logic mem_we;
  logic [7:0] mem_addr;
  logic [15:0] mem_wdata;
  logic [15:0] mem_rdata;
  //
  logic enable_tdo;
  logic tdo;
  assign TDO = enable_tdo? tdo: 1'bz;
  //
  jtag_ctrl jtag_ctrl (
    .tck(TCK),
    .jtag_rst_n(jtag_rst_n),
    .tms(TMS),
    .tdi(TDI),
    .tdo(tdo),
    .enable_tdo(enable_tdo),
    .ready(ready),
    .rdata(rdata),
    .sel(sel),
    .we(we),
    .addr(addr),
    .wdata(wdata)
  );
  //
  mem_ctrl mem_ctrl (
    .clk(clk),
    .sys_rst_n(sys_rst_n),
    .sel(sel),
    .we(we),
    .addr(addr),
    .wdata(wdata),
    .ready(ready),
    .rdata(rdata),
    .mem_rdata(mem_rdata),
    .mem_sel(mem_sel),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata)
  );
  //
  mem_model mem_model (
    .mem_rdata(mem_rdata),
    .mem_sel(mem_sel),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata)
  );
endmodule : jtag_top