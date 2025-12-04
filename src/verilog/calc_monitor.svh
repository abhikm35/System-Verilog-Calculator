class calc_monitor #(int DataSize, int AddrSize);
  logic written = 0;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    forever begin
      @(calcVif.cb);
      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time\n");
      end
      // Sample the transaction and send to scoreboard
      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        //Assign all values in the "trans" sequence item object with relevant signals from the clocking block
        trans.rdn_wr = calcVif.cb.wr_en;  // 1 for write, 0 for read
        trans.read_start_addr = calcVif.cb.read_start_addr;
        trans.read_end_addr = calcVif.cb.read_end_addr;
        trans.write_start_addr = calcVif.cb.write_start_addr;
        trans.write_end_addr = calcVif.cb.write_end_addr;
        trans.curr_rd_addr = calcVif.cb.curr_rd_addr;
        trans.curr_wr_addr = calcVif.cb.curr_wr_addr;
        trans.loc_sel = calcVif.cb.loc_sel;
        trans.initialize = calcVif.cb.initialize;

        if (trans.rdn_wr) // Write
        begin
          //Assign the data for the transaction from the clocking block correctly
          trans.lower_data = calcVif.cb.wr_data[DataSize-1:0];           // Lower 32 bits to SRAM A
          trans.upper_data = calcVif.cb.wr_data[DataSize*2-1:DataSize];  // Upper 32 bits to SRAM B

          if (!written) begin
            written = 1;
            // $display($stime, " Mon: Write to Addr: 0x%0x, Data to SRAM A (lower 32 bits): 0x%0x, Data to SRAM B (upper 32 bits): 0x%0x\n",
            //     trans.curr_wr_addr, trans.lower_data, trans.upper_data);
            mon_box.put(trans);
          end
        end
        else if (!trans.rdn_wr) // Read
        begin
          @(calcVif.cb);
          written = 0;
          //Assign the data for the transaction from the clocking block correctly
          trans.lower_data = calcVif.cb.rd_data[DataSize-1:0];           // SRAM A data
          trans.upper_data = calcVif.cb.rd_data[DataSize*2-1:DataSize];  // SRAM B data

          // $display($stime, " Mon: Read from Addr: 0x%0x, Data from SRAM A: 0x%0x, Data from SRAM B: 0x%0x\n",
          //     trans.curr_rd_addr, trans.upper_data, trans.lower_data);
          mon_box.put(trans);
        end
      end

      if (calcVif.cb.initialize) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();
        // Assign the right fields for the transaction from the clocking block signals that are
        // relevant to initializing SRAM
        // HINT: How do you differentiate which data belongs to which SRAM block?
        trans.initialize = 1'b1;
        trans.rdn_wr = 1'b1;  // Initialization is a write operation
        trans.read_start_addr = calcVif.cb.read_start_addr;
        trans.read_end_addr = calcVif.cb.read_end_addr;
        trans.write_start_addr = calcVif.cb.write_start_addr;
        trans.write_end_addr = calcVif.cb.write_end_addr;
        trans.curr_wr_addr = calcVif.cb.initialize_addr;
        trans.curr_rd_addr = calcVif.cb.initialize_addr;
        trans.loc_sel = calcVif.cb.initialize_loc_sel;

        // Differentiate which data belongs to which SRAM block using initialize_loc_sel
        if (calcVif.cb.initialize_loc_sel) begin
          // SRAM B (upper 32 bits)
          trans.upper_data = calcVif.cb.initialize_data;
          trans.lower_data = '0;
        end else begin
          // SRAM A (lower 32 bits)  
          trans.lower_data = calcVif.cb.initialize_data;
          trans.upper_data = '0;
        end

        // $display($stime, " Mon: Initialize SRAM; Write to SRAM %s, Addr: 0x%0x, Data: 0x%0x\n", 
        //         !calcVif.cb.initialize_loc_sel ? "A" : "B", calcVif.cb.initialize_addr, calcVif.cb.initialize_data);
        mon_box.put(trans);
      end
    end
  endtask : main

endclass : calc_monitor
