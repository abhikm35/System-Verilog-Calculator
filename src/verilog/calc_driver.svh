class calc_driver #(int DataSize = 32, int AddrSize = 10);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
      mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  task reset_task();
    // Apply active-high reset sequence to the DUT
    // From your RTL: always_ff @(posedge clk_i) if (rst_i) begin...
    // This indicates active-high reset
    $display("[DRIVER] Applying reset at time %0t", $time);
    calcVif.cb.reset <= 1'b1;
    repeat(3) @(calcVif.cb); // Hold reset for 3 clock cycles
    calcVif.cb.reset <= 1'b0;
    @(calcVif.cb); // Wait one more cycle for reset deassertion
    $display("[DRIVER] Reset released at time %0t", $time);
  endtask

  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    // Drive signals for SRAM initialization
    // block_sel: 0 = SRAM A (lower 32 bits), 1 = SRAM B (upper 32 bits)
    $display("[DRIVER] Initializing SRAM %s at addr 0x%0x with data 0x%0x at time %0t", 
             block_sel ? "B" : "A", addr, data, $time);
    
    // Set initialize flag to indicate SRAM initialization mode
    calcVif.cb.initialize <= 1'b1;
    calcVif.cb.initialize_addr <= addr;
    calcVif.cb.initialize_data <= data;
    // Set location select for buffer control
    calcVif.cb.initialize_loc_sel <= block_sel;
    
    @(calcVif.cb); // Wait one clock cycle for initialization
    
    // Clear initialization mode
    calcVif.cb.initialize <= 1'b0;

    $display("[DRIVER] SRAM %s initialization complete at time %0t", block_sel ? "B" : "A", $time);
  endtask : initialize_sram

  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr, input logic [AddrSize-1:0] read_end_addr,
      input logic [AddrSize-1:0] write_start_addr, input logic [AddrSize-1:0] write_end_addr,
      input bit direct = 1);

    int delay;
    calc_seq_item #(DataSize, AddrSize) trans;
    
    // Drive the calculation parameters to the DUT's interface
    // Based on top_lvl.sv inputs: read_start_addr, read_end_addr, write_start_addr, write_end_addr
    $display("[DRIVER] Starting calculation with Read[0x%0x:0x%0x] Write[0x%0x:0x%0x] at time %0t",
             read_start_addr, read_end_addr, write_start_addr, write_end_addr, $time);
    
    calcVif.cb.read_start_addr <= read_start_addr;
    calcVif.cb.read_end_addr <= read_end_addr;
    calcVif.cb.write_start_addr <= write_start_addr;
    calcVif.cb.write_end_addr <= write_end_addr;
    
    
    reset_task();
    @(calcVif.cb iff calcVif.cb.ready);

    if (!direct) begin // Random Mode
      if (drv_box.try_peek(trans)) begin
        delay = $urandom_range(0, 5); // Add a Random delay before the next transaction
        repeat (delay) begin
          @(calcVif.cb);
        end
      end
    end
    calcVif.cb.reset <= 1;
  endtask : start_calc

  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr, trans.read_end_addr, trans.write_start_addr, trans.write_end_addr, 0);
    end
  endtask : drive

endclass : calc_driver
