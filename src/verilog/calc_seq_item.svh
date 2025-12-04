class calc_seq_item #(int DataSize = 32, int AddrSize = 10);

  rand logic rdn_wr;
  rand logic [AddrSize-1:0] read_start_addr;
  rand logic [AddrSize-1:0] read_end_addr;
  rand logic [AddrSize-1:0] write_start_addr;
  rand logic [AddrSize-1:0] write_end_addr;
  rand logic [DataSize-1:0] lower_data;
  rand logic [DataSize-1:0] upper_data;
  rand logic [AddrSize-1:0] curr_rd_addr;
  rand logic [AddrSize-1:0] curr_wr_addr;
  rand logic loc_sel;
  rand logic initialize;

  // Constraint to make sure read end addresses are valid
  constraint read_end_gt_start {
    read_end_addr >= read_start_addr;
    read_start_addr >= 0;
    read_end_addr <= 511;  // SRAM depth is 512 words (0-511)
  }

  // Constraint to make sure write end addresses are valid
  constraint write_end_gt_start {
    write_end_addr >= write_start_addr;
    write_start_addr >= 0;
    write_end_addr <= 511;  // SRAM depth is 512 words (0-511)
  }

  // Constraint to make sure the read address ranges and write address ranges are valid
  constraint address_ranges_valid {
    // Current addresses should be within their respective ranges
    curr_rd_addr >= read_start_addr;
    curr_rd_addr <= read_end_addr;
    curr_wr_addr >= write_start_addr;
    curr_wr_addr <= write_end_addr;
    
    // All addresses must be within SRAM bounds (9-bit addressing for 512 words)
    curr_rd_addr <= 511;
    curr_wr_addr <= 511;
    
    // Reasonable range sizes to prevent overly large test ranges
    (read_end_addr - read_start_addr) <= 64;
    (write_end_addr - write_start_addr) <= 64;
    
    // Ensure ranges don't overlap to avoid conflicts
    // Either read range comes before write range OR write range comes before read range
    (read_end_addr < write_start_addr) || (write_end_addr < read_start_addr);
  }

  function new();
  endfunction

  function void display();
    $display($stime, " Rdn_Wr: %b Read Start Addr: 0x%0x, Read End Addr: 0x%0x, Write Start Addr: 0x%0x, Write End Addr: 0x%0x, Data 0x%0x, Current Read Addr: 0x%0x, Current Write Addr: 0x%0x, Buffer location select: %b, SRAM initialization: %b\n",
        rdn_wr, read_start_addr, read_end_addr, write_start_addr, write_end_addr, {upper_data, lower_data}, curr_rd_addr, curr_wr_addr, loc_sel, initialize);
  endfunction

endclass : calc_seq_item

