module controller import calculator_pkg::*;(
    input  logic                     clk_i,
    input  logic                     rst_i,

    // Memory Access
    input  logic [ADDR_W-1:0]        read_start_addr,
    input  logic [ADDR_W-1:0]        read_end_addr,
    input  logic [ADDR_W-1:0]        write_start_addr,
    input  logic [ADDR_W-1:0]        write_end_addr,

    // Control
    output logic                     write,
    output logic [ADDR_W-1:0]        w_addr,
    output logic [MEM_WORD_SIZE-1:0] w_data,

    output logic                     read,
    output logic [ADDR_W-1:0]        r_addr,
    input  logic [MEM_WORD_SIZE-1:0] r_data,

    // Buffer Control (1 = upper, 0 = lower)
    output logic                     buffer_control,

    // Operands to adder
    output logic [DATA_W-1:0]        op_a,
    output logic [DATA_W-1:0]        op_b,

    // 64-bit buffer from top-level result_buffer
    input  logic [MEM_WORD_SIZE-1:0] buff_result
);

    typedef enum logic [2:0] { S_IDLE, S_READ, S_ADD, S_WRITE, S_END } state_t;
    state_t state, next;

    logic [ADDR_W-1:0] r_ptr, w_ptr;
    logic [DATA_W-1:0] op_a_q, op_b_q;
    logic              half_next;
    logic              have_operands;
    logic              prewrite;

    assign r_addr = r_ptr;
    assign w_addr = w_ptr;
    assign w_data = buff_result;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state         <= S_IDLE;
            r_ptr         <= read_start_addr;
            w_ptr         <= write_start_addr;
            op_a_q        <= '0;
            op_b_q        <= '0;
            half_next     <= 1'b0;
            have_operands <= 1'b0;
            prewrite      <= 1'b0;
        end else begin
            state <= next;

            if (state == S_ADD) begin
                op_a_q <= r_data[DATA_W-1:0];
                op_b_q <= r_data[MEM_WORD_SIZE-1:DATA_W];
                r_ptr  <= r_ptr + 1;
            end

            if (state == S_ADD) begin
                half_next <= ~half_next;
            end

            if (state == S_WRITE && prewrite) begin
                w_ptr <= w_ptr + 1;
            end

            have_operands <= (state == S_READ);

            if (state == S_ADD && have_operands && half_next==1'b1) begin
                prewrite <= 1'b0;
            end else if (state == S_WRITE) begin
                prewrite <= ~prewrite;
            end else begin
                prewrite <= 1'b0;
            end
        end
    end

    always_comb begin
        next           = state;
        read           = 1'b0;
        write          = 1'b0;
        buffer_control = ~half_next; // CHANGED: inverted polarity
        op_a           = op_a_q;
        op_b           = op_b_q;

        unique case (state)
            S_IDLE:  next = S_READ;
            S_READ:  begin read = 1'b1; next = S_ADD; end
            S_ADD:   next = (half_next==1'b0) ? S_READ : S_WRITE;
            S_WRITE: begin
                        if (prewrite==1'b1) begin
                            write = 1'b1;
                            next  = (r_ptr > read_end_addr) ? S_END : S_READ;
                        end else begin
                            write = 1'b0;
                            next  = S_WRITE;
                        end
                     end
            S_END:   next = S_END;
            default: next = S_IDLE;
        endcase
    end

endmodule
