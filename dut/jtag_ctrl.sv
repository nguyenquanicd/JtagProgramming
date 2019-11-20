//--------------------------------------
//Project:  JTAG programming
//Function: JTAG controller
//Authors:  Nguyen Hung Quan
//Page:     VLSI Technology
//Website:  http://nguyenquanicd.blogspot.com/
//--------------------------------------
module jtag_ctrl (
  //JTAG interface
  input tck,
  input jtag_rst_n,
  input tms,
  input tdi,
  output logic tdo,
  output logic enable_tdo,
  //Memory controller interface
  input ready,
  input [15:0] rdata,
  output logic sel,
  output logic we,
  output logic [7:0] addr,
  output logic [15:0] wdata
  );
  //-------------------------------------------------------
  // Internal signals
  //-------------------------------------------------------
  enum logic [3:0] {
    EXIT2_DR = 4'h0,
    EXIT1_DR = 4'h1,
    SHIFT_DR = 4'h2,
    PAUSE_DR = 4'h3,
    SELECT_IR_SCAN = 4'h4,
    UPDATE_DR = 4'h5,
    CAPTURE_DR = 4'h6,
    SELECT_DR_SCAN = 4'h7,
    EXIT2_IR = 4'h8,
    EXIT1_IR = 4'h9,
    SHIFT_IR = 4'ha,
    PAUSE_IR = 4'hb,
    RUN_TEST_IDLE = 4'hc,
    UPDATE_IR = 4'hd,
    CAPTURE_IR = 4'he,
    TEST_LOGIC_RESET = 4'hf
  } jtag_state, jtag_next_state;
  localparam [3:0] BYPASS   = 4'b1111;
  localparam [3:0] SET_ADDR = 4'b1110;
  localparam [3:0] SET_DATA = 4'b1100;
  localparam [1:0] BUSY = 2'b01;
  localparam [1:0] OKAY = 2'b10;
  localparam [1:0] READ = 2'b01;
  localparam [1:0] WRITE= 2'b10;
  logic tck_n;
  logic cdr_state;
  logic sdr_state;
  logic udr_state;
  logic cir_state;
  logic sir_state;
  logic uir_state;
  logic [3:0] shift_ir_reg;
  logic [3:0] ir_reg;
  logic inst_setAddr;
  logic inst_setData;
  logic [17:0] shift_dr_reg;
  logic [17:0] dr_reg_in;
  logic [15:0] rdata_reg;
  logic [7:0] addr_reg;
  logic [15:0] wdata_reg;
  logic read_process;
  logic dr_tdo;
  logic read_en;
  logic write_en;
  logic sel_en;
  logic set_sel;
  logic clr_sel;
  logic mem_ctrl_idle;
  logic rising_ready;
  logic capture_rdata;
  logic shift_ir;
  logic shift_dr;
  logic [2:0] ready_sync;
  //-------------------------------------------------------
  // Invert clock
  //-------------------------------------------------------
  assign tck_n = ~tck;
  //-------------------------------------------------------
  // TAP FSM
  //-------------------------------------------------------
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      jtag_state <= TEST_LOGIC_RESET;
    else
      jtag_state <= jtag_next_state;
  end
  //
  always_comb begin
    unique case (jtag_state[3:0])
      TEST_LOGIC_RESET: jtag_next_state = tms? jtag_state: RUN_TEST_IDLE;
      RUN_TEST_IDLE: jtag_next_state = tms? SELECT_DR_SCAN: jtag_state;
      //DR stream
      SELECT_DR_SCAN: jtag_next_state = tms? SELECT_IR_SCAN: CAPTURE_DR;
      CAPTURE_DR: jtag_next_state = tms? EXIT1_DR: SHIFT_DR;
      SHIFT_DR: jtag_next_state = tms? EXIT1_DR: jtag_state;
      EXIT1_DR: jtag_next_state = tms? UPDATE_DR: PAUSE_DR;
      PAUSE_DR: jtag_next_state = tms? EXIT2_DR: jtag_state;
      EXIT2_DR: jtag_next_state = tms? UPDATE_DR: SHIFT_DR;
      UPDATE_DR: jtag_next_state = tms? SELECT_DR_SCAN: RUN_TEST_IDLE;
      //IR stream
      SELECT_IR_SCAN: jtag_next_state = tms? TEST_LOGIC_RESET: CAPTURE_IR;
      CAPTURE_IR: jtag_next_state = tms? EXIT1_IR: SHIFT_IR;
      SHIFT_IR: jtag_next_state = tms? EXIT1_IR: jtag_state;
      EXIT1_IR: jtag_next_state = tms? UPDATE_IR: PAUSE_IR;
      PAUSE_IR: jtag_next_state = tms? EXIT2_IR: jtag_state;
      EXIT2_IR: jtag_next_state = tms? UPDATE_IR: SHIFT_IR;
      UPDATE_IR: jtag_next_state = tms? SELECT_DR_SCAN: RUN_TEST_IDLE;
      default: jtag_next_state = jtag_state;
    endcase
  end
  //-------------------------------------------------------
  // Control logic
  //-------------------------------------------------------
  //
  assign cdr_state = (jtag_state == CAPTURE_DR);
  assign sdr_state = (jtag_state == SHIFT_DR);
  assign udr_state = (jtag_state == UPDATE_DR);
  assign cir_state = (jtag_state == CAPTURE_IR);
  assign sir_state = (jtag_state == SHIFT_IR);
  assign uir_state = (jtag_state == UPDATE_IR);
  //
  assign select_ir = jtag_state[3];
  always_ff @ (posedge tck_n, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      enable_tdo <= 1'b0;
    else
      enable_tdo <= sdr_state | sir_state;
  end
  always_ff @ (posedge tck_n, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      shift_ir <= 1'b0;
    else
      shift_ir <= sir_state;
  end
  assign capture_ir = cir_state;
  assign update_ir = uir_state;
  //
  always_ff @ (posedge tck_n, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      shift_dr <= 1'b0;
    else
      shift_dr <= sdr_state;
  end
  assign capture_dr = cdr_state;
  assign update_dr = udr_state;
  //-------------------------------------------------------
  // Instruction register (IR)
  //-------------------------------------------------------
  //Shift IR
  always_ff @ (posedge tck) begin
    if (shift_ir)
      shift_ir_reg[3:0] <= {tdi, shift_ir_reg[3:1]};
    else if (capture_ir)
      shift_ir_reg[3:0] <= 4'b0101;
  end
  //Output IR
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      ir_reg[3:0] <= BYPASS;
    else if (update_ir)
      ir_reg[3:0] <= shift_ir_reg[3:0];
  end
  //Instruction decoder
  assign inst_setAddr = (ir_reg[3:0] == SET_ADDR);
  assign inst_setData = (ir_reg[3:0] == SET_DATA);
  //-------------------------------------------------------
  // Data register (DR)
  //-------------------------------------------------------
  //Shift DR
  always_ff @ (posedge tck) begin
    if (shift_dr)
      shift_dr_reg[17:0] <= {tdi, shift_dr_reg[17:1]};
    else if (capture_dr)
      shift_dr_reg[17:0] <= dr_reg_in[17:0];
  end
  always_comb begin
    if (inst_setAddr)
      dr_reg_in[17:0] = {addr_reg[7:0], 10'd0};
    else if (inst_setData) begin
      if (mem_ctrl_idle) begin
        if (read_process)
          dr_reg_in[17:0] = {rdata_reg[15:0], OKAY};
        else
          dr_reg_in[17:0] = {wdata[15:0], OKAY};
      end
      else begin
        if (read_process)
          dr_reg_in[17:0] = {rdata_reg[15:0], BUSY};
        else
          dr_reg_in[17:0] = {wdata[15:0], BUSY};
      end
    end
    else
      dr_reg_in[17:0] = 18'd0;
  end
  //Read data from memory
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      rdata_reg[15:0] <= 16'd0;
    else if (inst_setData & read_process & capture_rdata)
      rdata_reg[15:0] <= rdata[15:0];
  end
  //Address register
  always_ff @ (posedge tck) begin
    if (!jtag_rst_n)
      addr_reg[7:0] <= 8'd0;
    else if (inst_setAddr & update_dr)
      addr_reg[7:0] <= shift_dr_reg[17:10];
  end
  //Write data register
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      wdata_reg[15:0] <= 16'd0;
    else if (write_en & update_dr)
      wdata_reg[15:0] <= shift_dr_reg[17:2];
  end
  //
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      read_process <= 1'b0;
    else if (update_dr)
      read_process <= read_en;
  end
  //-------------------------------------------------------
  // Output
  //-------------------------------------------------------
  //TDO
  always_ff @ (posedge tck_n) begin
    if (select_ir)
      tdo <= shift_ir_reg[0];
    else
      tdo <= dr_tdo;
  end
  always_comb begin
    unique case (ir_reg[3:0])
      BYPASS: dr_tdo = shift_dr_reg[17];
      SET_ADDR: dr_tdo = shift_dr_reg[10];
      default: dr_tdo = shift_dr_reg[0];
    endcase
  end
  //
  assign addr[7:0]   = addr_reg[7:0];
  assign wdata[15:0] = wdata_reg[15:0];
  //
  assign read_en  = inst_setData & (shift_dr_reg[1:0] == READ);
  assign write_en = inst_setData & (shift_dr_reg[1:0] == WRITE);
  assign sel_en   = (read_en | write_en) & mem_ctrl_idle;
  //
  assign set_sel = sel_en & ~sel & update_dr;
  assign clr_sel = rising_ready & sel;
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      sel <= 1'b0;
    else if (set_sel)
      sel <= 1'b1;
    else if (clr_sel)
      sel <= 1'b0;
  end
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      we <= 1'b0;
    else if (set_sel)
      we <= write_en;
  end
  //-------------------------------------------------------
  // synchronizer
  //-------------------------------------------------------
  always_ff @ (posedge tck, negedge jtag_rst_n) begin
    if (!jtag_rst_n)
      ready_sync[2:0] <= 3'b111;
    else
      ready_sync[2:0] <= {ready_sync[1:0], ready};
  end
  assign mem_ctrl_idle = ready_sync[2];
  assign rising_ready = ~ready_sync[2] & ready_sync[1];
  assign capture_rdata = rising_ready;
  
  
endmodule : jtag_ctrl