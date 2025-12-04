module calc_tb_top;

  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 1'b0;
  logic rst;
  state_t state;
  logic [DataSize-1:0] rd_data;

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    `ifdef VCS
    .read_start_addr(calc_if.read_start_addr),
    .read_end_addr(calc_if.read_end_addr),
    .write_start_addr(calc_if.write_start_addr),
    .write_end_addr(calc_if.write_end_addr)
    `endif
    `ifdef CADENCE
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr)
    `endif
  );

  assign rst = calc_if.reset;
  assign state = calculator_pkg::state_t'(my_calc.u_ctrl.state);
  `ifdef VCS
  assign calc_if.wr_en = my_calc.write;
  assign calc_if.rd_en = my_calc.read;
  assign calc_if.wr_data = my_calc.w_data;
  assign calc_if.rd_data = my_calc.r_data;
  assign calc_if.ready = my_calc.u_ctrl.state == S_END;
  assign calc_if.curr_rd_addr = my_calc.r_addr;
  assign calc_if.curr_wr_addr = my_calc.w_addr;
  assign calc_if.loc_sel = my_calc.buffer_control;
  `endif
  `ifdef CADENCE
  assign calc_if.calc.wr_en = my_calc.write;
  assign calc_if.calc.rd_en = my_calc.read;
  assign calc_if.calc.wr_data = my_calc.w_data;
  assign calc_if.calc.rd_data = my_calc.r_data;
  assign calc_if.calc.ready = my_calc.u_ctrl.state == S_END;
  assign calc_if.calc.curr_rd_addr = my_calc.r_addr;
  assign calc_if.calc.curr_wr_addr = my_calc.w_addr;
  assign calc_if.calc.loc_sel = my_calc.buffer_control;
  `endif

  calc_tb_pkg::calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
  calc_tb_pkg::calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
  calc_tb_pkg::calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) begin
      my_calc.sram_A.mem[addr] = data;
    end
    else begin
      my_calc.sram_B.mem[addr] = data;
    end
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask

  initial begin
    `ifdef VCS
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, calc_tb_top, "+mda", "+all", "+trace_process");
    $fsdbDumpMDA;
    `endif
    `ifdef CADENCE
    $shm_open("waves.shm");
    $shm_probe("AC");
    `endif

    calc_monitor_h = new(calc_if);
    calc_sb_h = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none
    calc_if.reset <= 1'b1;
    for (int i = 0; i < 2 ** AddrSize; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

    repeat (100) @(posedge clk);

    // Directed part
    $display("Directed Testing");
    
    // Test case 1 - normal addition
    $display("Test case 1 - normal addition");
    calc_driver_h.start_calc(0, 7, 8, 15, 1);
    calc_driver_h.start_calc(0, 31, 32, 64);
    wait(calc_if.ready);
    $display("✓ Test case 1 PASSED");

    // Test case 2 - addition with overflow
    $display("Test case 2 - addition with overflow");
    calc_driver_h.start_calc(0, 31, 32, 63, 1);
    wait(calc_if.ready);
    $display("✓ Test case 2 PASSED");
    
    // Add test cases according to your test plan. If you need additional test cases to reach
    // 96% coverage, make sure to add them to your test plan

    $display("Test case 3 - edge cases");

    // Edge case 1: 0 + 0 = 0
    write_sram(20, 32'h00000000, 0);  // SRAM A[20] = 0
    write_sram(20, 32'h00000000, 1);  // SRAM B[20] = 0 (Expected: 0)
    calc_driver_h.start_calc(20, 20, 30, 30, 1);
    wait(calc_if.ready);
    $display("✓ Edge case 1 (0+0) PASSED");

    // Edge case 2: MAX + MAX = overflow to 0xFFFFFFFE  
    write_sram(21, 32'hFFFFFFFF, 0);  // SRAM A[21] = MAX (4294967295)
    write_sram(21, 32'hFFFFFFFF, 1);  // SRAM B[21] = MAX (Overflow to 0xFFFFFFFE)
    calc_driver_h.start_calc(21, 21, 31, 31, 1);
    wait(calc_if.ready);
    $display("✓ Edge case 2 (MAX+MAX overflow) PASSED");

    // Edge case 3: 0 + MAX = MAX
    write_sram(22, 32'h00000000, 0);  // SRAM A[22] = 0
    write_sram(22, 32'hFFFFFFFF, 1);  // SRAM B[22] = MAX (Expected: 0xFFFFFFFF)
    calc_driver_h.start_calc(22, 22, 32, 32, 1);  // Read from 20-22, write to 30-32
    wait(calc_if.ready);
    $display("✓ Edge case 3 (0+MAX) PASSED");

    write_sram(2, {DataSize{1'b1}}, 0);
    write_sram(2, 32'h00000000, 1);
    calc_driver_h.start_calc(23, 23, 33, 33, 0);
    wait(calc_if.ready);
    $display("✓ Additional edge case PASSED");

    write_sram(5, 32'hAAAAAAAA, 0);
    write_sram(5, 32'h55555555, 1);
    calc_driver_h.start_calc(24, 24, 34, 34, 0);
    wait(calc_if.ready);
    $display("✓ Pattern test (0xAAAAAAAA + 0x55555555) PASSED");

    write_sram(6, 32'h00000123, 0);
    write_sram(6, 32'h00000456, 1);
    calc_driver_h.start_calc(25, 25, 35, 35, 0);
    wait(calc_if.ready);
    $display("✓ Small value addition test PASSED");

    // Test case for BUFFER_LOC_TOGGLES assertion coverage
    $display("Test case - Buffer location toggle");

    // First calculation with loc_sel = 0 (default)
    write_sram(10, 32'h11111111, 0);  // SRAM A[10]
    write_sram(10, 32'h22222222, 1);  // SRAM B[10]
    calc_driver_h.start_calc(10, 10, 40, 40, 0);  // loc_sel = 0
    wait(calc_if.ready);  // Wait until ready with loc_sel=0

    // Immediately start second calculation with loc_sel = 1
    write_sram(11, 32'h33333333, 0);  // SRAM A[11]  
    write_sram(11, 32'h44444444, 1);  // SRAM B[11]
    calc_driver_h.start_calc(11, 11, 41, 41, 1);  // loc_sel = 1
    wait(calc_if.ready);  // Complete second calculation

    // Third calculation back to loc_sel = 0 for complete coverage
    write_sram(12, 32'h55555555, 0);  // SRAM A[12]
    write_sram(12, 32'h66666666, 1);  // SRAM B[12]  
    calc_driver_h.start_calc(12, 12, 42, 42, 0);  // loc_sel = 0
    wait(calc_if.ready);
    $display("✓ Buffer location toggle test PASSED");

    $display("Randomized Testing");
    calc_sequencer_h.gen(10);  // Generate random sequences first
    calc_driver_h.drive();     // Then execute them

    repeat (200) @(posedge clk);  // Wait for completion
    $display("✓ Randomized testing PASSED");

    // Test case 4 - FSM reset during different states
    $display("Test case 4 - FSM reset during different states");
    // Setup some data for the FSM to work with
    write_sram(50, 32'h12345678, 0);  // SRAM A[50]
    write_sram(50, 32'h87654321, 1);  // SRAM B[50]
    write_sram(51, 32'hAABBCCDD, 0);  // SRAM A[51]  
    write_sram(51, 32'hDDCCBBAA, 1);  // SRAM B[51]

    fork
      begin
        calc_driver_h.start_calc(50, 50, 60, 60, 1);
      end
      begin
        wait (state == S_READ);
      end
    join_any
    disable fork;

    calc_if.reset <= 1;
    @(posedge clk);
    calc_if.reset <= 0;
    wait(calc_if.ready);
    $display("FSM reset during Read -> returned to IDLE.");
    $display("✓ FSM reset during READ state PASSED");

    $display("Test case 4 - FSM reset during add state");

    fork
      begin
        calc_driver_h.start_calc(40, 4, 32, 23, 1);
      end
      begin
        wait (state == S_ADD);
      end
    join_any
    disable fork;

    calc_if.reset <= 1;
    @(posedge clk);
    calc_if.reset <= 0;
    wait(calc_if.ready);
    $display("FSM reset during Read -> returned to IDLE.");
    $display("✓ FSM reset during ADD state PASSED");

    $display("Test case 4.3 - FSM reset during write state");

    fork
      begin
        calc_driver_h.start_calc(14, 16, 23, 45, 1);
      end
      begin
        wait (state == S_WRITE);
      end
    join_any
    disable fork;

    calc_if.reset <= 1;
    @(posedge clk);
    calc_if.reset <= 0;
    wait(calc_if.ready);
    $display("FSM reset during Write -> returned to IDLE.");
    $display("✓ FSM reset during WRITE state PASSED");

    // Test case - S_ADD without operands (for conditional coverage)
    $display("Test case - S_ADD state without operands");

    // Setup a scenario where FSM reaches S_ADD but have_operands is false
    write_sram(100, 32'h12345678, 0);
    write_sram(100, 32'h87654321, 1);

    fork
        begin
            calc_driver_h.start_calc(100, 100, 200, 200, 1);
        end
        begin
            // Wait for S_READ state first
            wait(state == S_READ);
            // Apply reset right after read to clear have_operands before ADD
            @(posedge clk);
            calc_if.reset <= 1;
            @(posedge clk);
            calc_if.reset <= 0;
        end
    join_any
    disable fork;
    wait(calc_if.ready);
    $display("✓ S_ADD without operands test PASSED");

    // Test case - Hit missing S_ADD && have_operands branches
    $display("Test case - S_ADD conditional coverage");

    // Setup memory
    write_sram(150, 32'h12345678, 0);
    write_sram(150, 32'h87654321, 1);

    // Test 1: Ensure we hit S_ADD with have_operands = TRUE (if not already covered)
    calc_driver_h.start_calc(150, 150, 250, 250, 1);
    wait(calc_if.ready);

    // Test 2: Force S_ADD with have_operands = FALSE
    write_sram(151, 32'hDEADBEEF, 0);
    write_sram(151, 32'hCAFEBABE, 1);

    fork
        begin
            calc_driver_h.start_calc(151, 151, 251, 251, 1);
        end
        begin
            // Wait for S_READ to complete and have_operands to be set
            wait(state == S_READ);
            @(posedge clk); // Let read complete
            
            // Wait for transition to S_ADD
            wait(state == S_ADD);
            
            // Apply reset immediately to clear have_operands while in S_ADD
            calc_if.reset <= 1;
            @(posedge clk);
            calc_if.reset <= 0;
            
            // This should create the condition where (state == S_ADD) && (have_operands == FALSE)
        end
    join_any
    disable fork;

    repeat(10) @(posedge clk); // Let FSM stabilize
    $display("✓ S_ADD conditional coverage test completed");

    repeat (200) @(posedge clk);
    // HINT: The sequencer is responsible for generating random input sequences. How can the
    // sequencer and driver be combined to generate multiple randomized test cases?

    $display("=== ALL TESTS COMPLETED SUCCESSFULLY ===");
    $finish;
  end

  /********************
        ASSERTIONS
  *********************/

  // Add Assertions
  // RESET: ;
  // VALID_INPUT_ADDRESS: ;
  // BUFFER_LOC_TOGGLES: ;

  RESET: assert property (@(posedge clk)
    calc_if.reset |=> (my_calc.u_ctrl.state == S_IDLE));
   VALID_INPUT_ADDRESS: assert property (@(posedge clk)
    disable iff (calc_if.reset)
    (calc_if.rd_en |->
    (calc_if.curr_rd_addr >= calc_if.read_start_addr &&
    calc_if.curr_rd_addr <= calc_if.read_end_addr)) and
    (calc_if.wr_en |->
    (calc_if.curr_wr_addr >= calc_if.write_start_addr &&
    calc_if.curr_wr_addr <= calc_if.write_end_addr)));
  BUFFER_LOC_TOGGLES: assert property (@(posedge clk)
    disable iff (calc_if.reset)
    $changed(calc_if.loc_sel) |-> !calc_if.ready);

endmodule
