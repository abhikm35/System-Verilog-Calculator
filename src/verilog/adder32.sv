/*
* Module describing a 32-bit ripple carry adder, with no carry output or input
*/
module adder32 import calculator_pkg::*; (
    input  logic [DATA_W - 1 : 0] a_i,
    input  logic [DATA_W - 1 : 0] b_i,
    output logic [DATA_W - 1 : 0] sum_o
);

    // internal carry chain; carry[0] is the initial 0, carry[DATA_W] is final carry out (unused)
    logic [DATA_W:0] carry;
    assign carry[0] = 1'b0;  // no carry-in

    // chain together DATA_W full adders
    genvar i;
    generate
        for (i = 0; i < DATA_W; i = i + 1) begin : ADD_STAGE
            full_adder one_bit (
                .a    (a_i[i]),
                .b    (b_i[i]),
                .cin  (carry[i]),
                .s  (sum_o[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

endmodule