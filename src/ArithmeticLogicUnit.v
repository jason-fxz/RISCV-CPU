`include "config.v"

module ALU(
        input wire  clk_in,        // system clock signal
        input wire  rst_in,        // reset signal
        input wire  rdy_in,        // ready signal, pause cpu when low

        // from reservation station
        input wire valid,                               // valid signal
        input wire [31 : 0] r1,                         // operand 1
        input wire [31 : 0] r2,                         // operand 2
        input wire [`ROB_SIZE_BIT - 1 : 0] rob_idx_in,  // rob index
        input wire [4 : 0] rs_op_type,                  // operation type

        output reg [31 : 0] result,                     // alu result
        output reg [`ROB_SIZE_BIT - 1 : 0] rob_idx,     // rob index
        output reg ready                                // ready signal
    );

    // Funct3 Code: arith R-type / arith I-type
    localparam ADDSUB = 5'b000; // Add: 000 000 / Sub: 000 010
    localparam AND    = 5'b111;
    localparam OR     = 5'b110;
    localparam XOR    = 5'b100;
    localparam SLL    = 5'b001;
    localparam SRLA   = 5'b101; // SRL: 101 000 / SRA: 101 010
    localparam SLT    = 5'b010;
    localparam SLTU   = 5'b011;

    // Funct3 Code: branch B-type
    localparam BEQ    = 5'b000;
    localparam BNE    = 5'b001;
    localparam BLT    = 5'b100;
    localparam BGE    = 5'b101;
    localparam BLTU   = 5'b110;
    localparam BGEU   = 5'b111;


    always @()




endmodule //ALU
