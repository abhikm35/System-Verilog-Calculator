class calc_sb #(int DataSize = 32, int AddrSize = 10);

  // Signals needed for the golden model implementation in the scoreboard
  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  logic second_read = 0;
  int golden_lower_data;
  int golden_upper_data;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);

      // Initialization transaction: populate golden memory
      if (trans.initialize) begin
        if (!trans.loc_sel) begin
          mem_a[trans.curr_wr_addr] = trans.lower_data;  // FIXED: use curr_wr_addr
        end else begin
          mem_b[trans.curr_wr_addr] = trans.upper_data;  // FIXED: use curr_wr_addr
        end
        $display($stime, " SB: Initialized SRAM %s Addr: 0x%0x Data: 0x%0x", 
                 !trans.loc_sel ? "A" : "B", trans.curr_wr_addr,  // FIXED: use curr_wr_addr
                 !trans.loc_sel ? trans.lower_data : trans.upper_data);
        continue;
      end

      // Read transaction
      if (!trans.rdn_wr) begin
        if (!second_read) begin
          // First read: store expected data from golden model
          golden_lower_data = mem_a[trans.curr_rd_addr];
          golden_upper_data = mem_b[trans.curr_rd_addr];
          second_read = 1;
          $display($stime, " SB: First Read Addr: 0x%0x, Expected LOWER: 0x%0x UPPER: 0x%0x",
                   trans.curr_rd_addr, golden_lower_data, golden_upper_data);
        end else begin
          // Second read: compare with DUT output
          if (trans.lower_data !== golden_lower_data)
            $error($stime, " SB: Mismatch LOWER data at addr 0x%0x, Expected: 0x%0x, Got: 0x%0x",
                   trans.curr_rd_addr, golden_lower_data, trans.lower_data);
          if (trans.upper_data !== golden_upper_data)
            $error($stime, " SB: Mismatch UPPER data at addr 0x%0x, Expected: 0x%0x, Got: 0x%0x",
                   trans.curr_rd_addr, golden_upper_data, trans.upper_data);
          $display($stime, " SB: Second Read Addr: 0x%0x, Actual LOWER: 0x%0x UPPER: 0x%0x",
                   trans.curr_rd_addr, trans.lower_data, trans.upper_data);
          second_read = 0;
        end
      end

      // Write transaction
      if (trans.rdn_wr && !trans.initialize) begin  // FIXED: exclude initialization writes
        // Compute expected golden data (addition of the two operands from previous reads)
        int expected_lower = golden_lower_data + golden_upper_data;
        // For 32-bit adder with 64-bit result buffer, check both parts
        int expected_upper = 0; // Assuming no carry propagation to upper 32 bits for simple addition
        
        if (trans.lower_data !== expected_lower[DataSize-1:0])  // Mask to 32 bits
          $error($stime, " SB: Mismatch on WRITE LOWER data at addr 0x%0x, Expected: 0x%0x, Got: 0x%0x",
                 trans.curr_wr_addr, expected_lower[DataSize-1:0], trans.lower_data);
        
        if (trans.upper_data !== expected_upper)
          $error($stime, " SB: Mismatch on WRITE UPPER data at addr 0x%0x, Expected: 0x%0x, Got: 0x%0x",
                 trans.curr_wr_addr, expected_upper, trans.upper_data);
        
        // Update golden memory after write
        mem_a[trans.curr_wr_addr] = trans.lower_data;
        mem_b[trans.curr_wr_addr] = trans.upper_data;
        
        $display($stime, " SB: Write Addr: 0x%0x, Computed: 0x%0x+0x%0x=0x%0x, Actual LOWER: 0x%0x UPPER: 0x%0x",
                 trans.curr_wr_addr, golden_lower_data, golden_upper_data, expected_lower,
                 trans.lower_data, trans.upper_data);
      end
    end
  endtask

endclass : calc_sb

