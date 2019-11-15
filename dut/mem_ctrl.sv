//--------------------------------------
//Project:  JTAG programming
//Function: Memory controller
//Authors:  Nguyen Hung Quan
//Page:     VLSI Technology
//Website:  http://nguyenquanicd.blogspot.com/
//--------------------------------------
module mem_ctrl (
  input clk,
  input sys_rst_n,
  //from JTAG controller
  input sel,
  input we,
  input [7:0] addr,
  input [15:0] wdata,
  output logic ready,
  output logic [15:0] rdata,
  //Memory interface
  input [15:0] mem_rdata,
  output logic mem_sel,
  output logic mem_we,
  output logic [7:0] mem_addr,
  output logic [15:0] mem_wdata
  );
  enum logic {
    MEM_IDLE = 1'b0,
    MEM_ACCESS = 1'b1
  } mem_state, mem_next_state;
  localparam [15:0] ACC_DELAY = 16'h000f;
  logic [2:0] sel_sync;
  logic rising_sel;
  logic idle_state;
  logic acc_state;
  logic acc_complete;
  logic [15:0] acc_counter;
  //--------------------------------------
  // Synchronizer
  //--------------------------------------
  always_ff @ (posedge clk, negedge sys_rst_n) begin
    if (!sys_rst_n)
      sel_sync[2:0] <= 3'b000;
    else
      sel_sync[2:0] <= {sel_sync[1:0], sel};
  end
  assign rising_sel = ~sel_sync[2] & sel_sync[1];
  //--------------------------------------
  //FSM
  //--------------------------------------
  always_ff @ (posedge clk, negedge sys_rst_n) begin
    if (!sys_rst_n)
      mem_state <= MEM_IDLE;
    else if (mem_state == MEM_IDLE) begin
      if (rising_sel)
        mem_state <= MEM_ACCESS;
    end
    else begin
      if (acc_complete)
        mem_state <= MEM_IDLE;
    end
  end
  assign idle_state = (mem_state == MEM_IDLE);
  assign acc_state  = (mem_state == MEM_ACCESS);
  //--------------------------------------
  //Access counter
  //--------------------------------------
  always_ff @ (posedge clk, negedge sys_rst_n) begin
    if (!sys_rst_n)
      acc_counter[15:0] <= 16'd0;
    else if (acc_state)
      acc_counter[15:0] <= acc_counter[15:0] + 16'd1;
    else
      acc_counter[15:0] <= 16'd0;
  end
  assign acc_complete = (acc_counter[15:0] == ACC_DELAY);
  //--------------------------------------
  //Output
  //--------------------------------------
  always_ff @ (posedge clk) begin
    if (rising_sel) begin
      mem_we <= we;
      mem_addr[7:0] <= addr[7:0];
      mem_wdata[15:0] <= wdata[15:0];
    end
  end
  //
  assign mem_sel = acc_state;
  assign ready   = idle_state;
  //
  always_ff @ (posedge clk) begin
    if (acc_complete & !mem_we)
      rdata[15:0] <= mem_rdata[15:0];
  end
endmodule : mem_ctrl
