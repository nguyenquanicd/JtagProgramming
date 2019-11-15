//--------------------------------------
//Project:  JTAG programming
//Function: Memory model - only use to simulate, NOT for synthesing
//Authors:  Nguyen Hung Quan
//Page:     VLSI Technology
//Website:  http://nguyenquanicd.blogspot.com/
//--------------------------------------
module mem_model (
  output logic [15:0] mem_rdata,
  input mem_sel,
  input mem_we,
  input [7:0] mem_addr,
  input [15:0] mem_wdata
  );
  localparam TWRITE  = 16'h15;
  localparam TTRANS  = 16'h9;
  logic [15:0] memArray[255:0];
  logic inClk;
  logic [15:0] inCounter;
  logic inWe;
  logic inRe;
  //Internal clock
  initial begin : clockGen
    inClk <= 1'b0;
    forever #1ns inClk <= !inClk;
  end : clockGen
  //Timing monitor
  always @ (posedge inClk) begin : timingCounter
    if (mem_sel)
      inCounter[15:0] <= inCounter[15:0] + 16'd1;
    else
      inCounter[15:0] <= 16'd0;
  end : timingCounter
  assign inWe = (inCounter >= TWRITE);
  assign inRe = (inCounter > TTRANS);
  //Write to memory
  always @ (posedge inClk) begin : memoryArray
    if (inWe & mem_we)
      memArray[mem_addr] <= mem_wdata;
  end : memoryArray
  //Read from memory
  always @ (posedge inClk) begin
    if (inRe & ~mem_we)
      mem_rdata[15:0] <= memArray[mem_addr];
    else
      mem_rdata[15:0] <= 16'hxxxx;
  end
endmodule : mem_model