/* 
 * This top_level module integrates the controller, memory, adder, and result buffer to form a complete calculator system.
 * It handles memory reads/writes, arithmetic operations, and result buffering.
 */
module top_lvl import calculator_pkg::*; (
    input  logic                 clk,
    input  logic                 rst,

    // Memory Config
    input  logic [ADDR_W-1:0]    read_start_addr,
    input  logic [ADDR_W-1:0]    read_end_addr,
    input  logic [ADDR_W-1:0]    write_start_addr,
    input  logic [ADDR_W-1:0]    write_end_addr
);

    // ----------------------------------------------------------------
    // Internal interconnects
    // ----------------------------------------------------------------
    logic                        read;
    logic                        write;
    logic [ADDR_W-1:0]           r_addr;
    logic [ADDR_W-1:0]           w_addr;
    logic [MEM_WORD_SIZE-1:0]    w_data;

    // Two 32-bit SRAM read ports (lower/upper halves)
    logic [31:0]                 r_data_A;
    logic [31:0]                 r_data_B;

    // 64-bit read data to controller composed from A (lower) and B (upper)
    logic [MEM_WORD_SIZE-1:0]    r_data;

    // Adder operands/results and buffer control
    logic [DATA_W-1:0]           op_a;
    logic [DATA_W-1:0]           op_b;
    logic [DATA_W-1:0]           result32;
    logic                        buffer_control;
    logic [MEM_WORD_SIZE-1:0]    buff_result;

    // Combine SRAM_A (lower 32) and SRAM_B (upper 32) into 64-bit bus
    assign r_data = { r_data_B, r_data_A };

    // ----------------------------------------------------------------
    // Controller
    // ----------------------------------------------------------------
    controller u_ctrl (
        .clk_i           (clk),
        .rst_i           (rst),
        .read_start_addr (read_start_addr),
        .read_end_addr   (read_end_addr),
        .write_start_addr(write_start_addr),
        .write_end_addr  (write_end_addr),

        .write           (write),
        .w_addr          (w_addr),
        .w_data          (w_data),

        .read            (read),
        .r_addr          (r_addr),
        .r_data          (r_data),

        .buffer_control  (buffer_control),

        .op_a            (op_a),
        .op_b            (op_b),

        .buff_result     (buff_result)
    );

    // ----------------------------------------------------------------
    // SRAM A (lower 32 bits)
    // Port 0: write, Port 1: read
    // ----------------------------------------------------------------
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_A (
        // Port 0 (write)
        .clk0    (clk),
        .csb0    (~write),       // active-low chip select for write
        .web0    (~write),       // active-low write enable
        .wmask0  (4'hF),         // write all bytes
        .addr0   (w_addr[8:0]),  // macro depth is 512 words
        .din0    (w_data[31:0]),
        .dout0   (),

        // Port 1 (read)
        .clk1    (clk),
        .csb1    (~read),        // active-low read enable
        .addr1   (r_addr[8:0]),
        .dout1   (r_data_A)
    );

    // ----------------------------------------------------------------
    // SRAM B (upper 32 bits)
    // Port 0: write, Port 1: read
    // ----------------------------------------------------------------
    sky130_sram_2kbyte_1rw1r_32x512_8 sram_B (
        // Port 0 (write)
        .clk0    (clk),
        .csb0    (~write),
        .web0    (~write),
        .wmask0  (4'hF),
        .addr0   (w_addr[8:0]),
        .din0    (w_data[63:32]),
        .dout0   (),

        // Port 1 (read)
        .clk1    (clk),
        .csb1    (~read),
        .addr1   (r_addr[8:0]),
        .dout1   (r_data_B)
    );

    // ----------------------------------------------------------------
    // Adder (32-bit)
    // ----------------------------------------------------------------
    adder32 u_adder (
        .a_i   (op_a),
        .b_i   (op_b),
        .sum_o (result32)
    );

    // ----------------------------------------------------------------
    // Result buffer (64-bit)
    // ----------------------------------------------------------------
    result_buffer u_resbuf (
        .clk_i     (clk),
        .rst_i     (rst),
        .result_i  (result32),
        .loc_sel   (buffer_control),
        .buffer_o  (buff_result)
    );

    // NOTE: Removed "assign w_data = buff_result;" to avoid multiple drivers on w_data. [2][1]

endmodule