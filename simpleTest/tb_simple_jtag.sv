//--------------------------------------
//Project:  JTAG programming
//Function: JTAG TOP module
//Authors:  Nguyen Hung Quan
//Page:     VLSI Technology
//Website:  http://nguyenquanicd.blogspot.com/
//--------------------------------------
`define TCK50 10ns
`define CLK50 3ns
`define tapState jtag_top.jtag_ctrl.jtag_state
`define tapIr    jtag_top.jtag_ctrl.ir_reg
`define tapAddr  jtag_top.jtag_ctrl.addr_reg
`define tapWData jtag_top.jtag_ctrl.wdata_reg
`define tapRData jtag_top.jtag_ctrl.rdata_reg
module tb_simple_jtag;
  string taskName;
  localparam [3:0] BYPASS   = 4'b1111;
  localparam [3:0] SET_ADDR = 4'b1110;
  localparam [3:0] SET_DATA = 4'b1100;
  localparam [1:0] BUSY = 2'b01;
  localparam [1:0] OKAY = 2'b10;
  localparam [1:0] READ = 2'b01;
  localparam [1:0] WRITE= 2'b10;
  localparam [1:0] CHECK= 2'b00;
  localparam  EXIT2_DR = 4'h0;
  localparam  EXIT1_DR = 4'h1;
  localparam  SHIFT_DR = 4'h2;
  localparam  PAUSE_DR = 4'h3;
  localparam  SELECT_IR_SCAN = 4'h4;
  localparam  UPDATE_DR = 4'h5;
  localparam  CAPTURE_DR = 4'h6;
  localparam  SELECT_DR_SCAN = 4'h7;
  localparam  EXIT2_IR = 4'h8;
  localparam  EXIT1_IR = 4'h9;
  localparam  SHIFT_IR = 4'ha;
  localparam  PAUSE_IR = 4'hb;
  localparam  RUN_TEST_IDLE = 4'hc;
  localparam  UPDATE_IR = 4'hd;
  localparam  CAPTURE_IR = 4'he;
  localparam  TEST_LOGIC_RESET = 4'hf;
  int  BIT_NUM = 8;
  //JTAG interface
  logic TCK;
  logic jtag_rst_n;
  logic TMS;
  logic TDI;
  wire  TDO;
  //Memory controller interface
  logic clk;
  logic sys_rst_n;
  //
  logic [3:0]  ir;
  logic [17:0] dr;
  logic [3:0]  capIr;
  logic [7:0]  capAddr;
  logic [17:0] capData;
  logic [3:0]  tapInst;
  //
  jtag_top jtag_top (
    //JTAG interface
    .TCK,
    .jtag_rst_n,
    .TMS,
    .TDI,
    .TDO,
    //Memory controller interface
    .clk,
    .sys_rst_n
  );
  //
  assign tapInst  = jtag_top.jtag_ctrl.ir_reg;
  //Capture IR
  always @ (posedge TCK) begin
    if (`tapState == SHIFT_IR)
      capIr <= {TDO, capIr[3:1]};
  end
  //Capture Address
  always @ (posedge TCK) begin
    if (`tapState == SHIFT_DR && `tapIr == SET_ADDR)
      capAddr <= {TDO, capAddr[7:1]};
  end
  //Capture Data
  always @ (posedge TCK) begin
    if (`tapState == SHIFT_DR && (`tapIr == SET_DATA || `tapIr == BYPASS))
      capData <= {TDO, capData[17:1]};
  end
  //clock is running free
  initial begin : clock_reset_jtag
    jtag_rst_n <= 1'b0;
    TCK <= 1'b1;
    #(3*`TCK50)
    jtag_rst_n <= 1'b1;
    forever #`TCK50 TCK <= !TCK;
  end : clock_reset_jtag
  initial begin : clock_reset_sys
    sys_rst_n <= 1'b0;
    clk <= 1'b1;
    #(3*`TCK50)
    sys_rst_n <= 1'b1;
    forever #`CLK50 clk <= !clk;
  end : clock_reset_sys
  //Main body
  initial begin : main
    TMS = 1'b1;
    goto_IDLE;
    //Test BYPASS
    ir = BYPASS;
    send_IR;
    //
    dr = 18'b01111111_11111010_10;
    BIT_NUM = 5;
    send_DR;
    //Test SET_ADDR
    ir = SET_ADDR;
    send_IR;
    //
    dr = 18'b01111111_11000000_11;
    BIT_NUM = 8;
    send_DR;
    //Test SET_DATA (WRITE)
    ir = SET_DATA;
    send_IR;
    //
    dr = 18'b01111110_10000001_10;
    BIT_NUM = 18;
    send_DR;
    //Test SET_DATA (CHECK)
    checkStatus;
    //Test SET_DATA (READ)
    //
    dr = 18'b00000000_00000000_01;
    BIT_NUM = 18;
    send_DR;
    //Test SET_DATA (CHECK)
    checkStatus;
    #234
    $stop;
  end : main
  //
  //Task
  //
  task checkStatus;
    while (1) begin
      dr = 18'b00000000_11111111_00;
      BIT_NUM = 18;
      send_DR;
      if (capData[1:0] == OKAY) break;
    end
  endtask : checkStatus
  //
  task goto_IDLE;
    begin
      @ (negedge TCK);
      taskName <= "goto_IDLE";
      TMS <= 1'b0;
      @ (negedge TCK);
      printState;
      $strobe ("----------------------------------------\n");
    end
  endtask : goto_IDLE
  //
  task send_IR;
    begin
      @ (negedge TCK);
      taskName <= "send_IR";
      TMS <= 1'b1;
      repeat (2) @ (negedge TCK); //SELECT_IR_SCAN
      printState;
      TMS <= 1'b0;
      repeat (2) @ (negedge TCK); //SHIFT_IR
      printState;
      shiftIr; //Shift IR
      TMS <= 1'b1;
      repeat (2) @ (negedge TCK); //UPDATE_IR
      printState;
      TMS <= 1'b0;
      repeat (1) @ (negedge TCK); //RUN_TEST_IDLE
      printState;
      printRegTdo;
      printReg;
      repeat (1) @ (negedge TCK);
      $strobe ("[END IR] ----------------------------------------\n");
    end
  endtask : send_IR
  //
  task send_DR;
    begin
      @ (negedge TCK);
      taskName <= "send_DR";
      TMS <= 1'b1;
      repeat (1) @ (negedge TCK); //SELECT_DR_SCAN
      printState;
      TMS <= 1'b0;
      repeat (2) @ (negedge TCK); //SHIFT_DR
      printState;
      shiftDr; //Shift DR
      TMS <= 1'b1;
      repeat (2) @ (negedge TCK); //UPDATE_DR
      printState;
      TMS <= 1'b0;
      repeat (1) @ (negedge TCK); //RUN_TEST_IDLE
      printState;
      printRegTdo;
      printReg;
      repeat (1) @ (negedge TCK);
      $strobe ("[END DR] ----------------------------------------\n");
    end
  endtask : send_DR
  //
  task printState;
    begin
      $strobe ("[%s] TAP state : %s", taskName, `tapState);
    end
  endtask : printState
  task printReg;
    begin
      $strobe ("[%s] tapIr    : %4b", taskName, `tapIr);
      $strobe ("[%s] tapAddr  : %8b", taskName, `tapAddr);
      $strobe ("[%s] tapWData : %16b", taskName, `tapWData);
      $strobe ("[%s] tapRData : %16b", taskName, `tapRData);
    end
  endtask : printReg
  task printRegTdo;
    begin
      $strobe ("[%s] capIr from TDO   : %4b", taskName, capIr);
      $strobe ("[%s] capAddr from TDO : %8b", taskName, capAddr);
      $strobe ("[%s] capData from TDO : %18b", taskName, capData);
    end
  endtask : printRegTdo
  //
  task shiftIr;
    begin
      taskName <= "IR";
      case (ir)
        BYPASS: $strobe ("Load instruction: BYPASS");
        SET_ADDR: $strobe ("Load instruction: SET_ADDR");
        SET_DATA: $strobe ("Load instruction: SET_DATA");
        default: $strobe ("Load instruction: UN-Supported");
      endcase
      for (int i = 0; i < 3; i++) begin
        TDI = ir[0];
        @ (negedge TCK);
        ir  = ir >> 1;
        TDI = ir[0];
      end
    end
  endtask : shiftIr
  //
  task shiftDr;
    begin
      taskName <= "DR";
      if (`tapIr == BYPASS)
        $strobe ("Shift DATA in BYPASS");
      else if (`tapIr == SET_ADDR)
        $strobe ("Shift Address in SET_ADDR");
      else begin
        case (dr[1:0])
          CHECK: $strobe ("Load request CHECK in SET_DATA");
          READ: $strobe ("Load request READ in SET_DATA");
          WRITE: $strobe ("Load request WRITE in SET_DATA");
          default: $strobe ("Load request: UN-Supported");
        endcase
      end
      for (int j = 0; j < BIT_NUM-1; j++) begin
        //$strobe ("[%s] dr = %18b", taskName, dr);
        TDI = dr[0];
        @ (negedge TCK);
        dr  = dr >> 1;
        TDI = dr[0];
      end
    end
  endtask : shiftDr
  //
endmodule : tb_simple_jtag