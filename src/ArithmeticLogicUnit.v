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
    input wire [`RS_TYPE_BIT - 1 : 0] rs_op_type,   // operation type

    output reg [31 : 0] result,                     // alu result
    output reg [`ROB_SIZE_BIT - 1 : 0] rob_idx,     // rob index
    output reg ready                                // ready signal
);

    // Funct3 Code: arith R-type / arith I-type  2b'0x
    localparam ADDSUB = 5'b000; // Add: 000 000 / Sub: 000 010
    localparam AND    = 5'b111;
    localparam OR     = 5'b110;
    localparam XOR    = 5'b100;
    localparam SLL    = 5'b001;
    localparam SRLA   = 5'b101; // SRL: 101 000 / SRA: 101 010
    localparam SLT    = 5'b010;
    localparam SLTU   = 5'b011;

    // Funct3 Code: branch B-type 2b'10
    localparam BEQ    = 5'b000;
    localparam BNE    = 5'b001;
    localparam BLT    = 5'b100;
    localparam BGE    = 5'b101;
    localparam BLTU   = 5'b110;
    localparam BGEU   = 5'b111;


    always @(posedge clk_in) begin
        if (rst_in) begin
            ready <= 0;
            rob_idx <= 0;
            result <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!valid) begin
            ready <= 0; // Input are not valid
        end
        else begin
            ready <= 1'b1;
            rob_idx <= rob_idx_in;

            // 
            if (rs_op_type[4] == 0) begin // 0yxxx
                case (rs_op_type[2:0])
                    ADDSUB: result <= rs_op_type[3] ? r1 - r2 : r1 + r2;
                    AND:    result <= r1 & r2;
                    OR:     result <= r1 | r2;
                    XOR:    result <= r1 ^ r2;
                    SLL:    result <= r1 << r2[4:0];
                    SRLA:   result <= rs_op_type[3] ? $signed(r1) >>> r2[4:0] : r1 >> r2[4:0];
                    SLT:    result <= $signed(r1) < $signed(r2) ? 1 : 0;
                    SLTU:   result <= $unsigned(r1) < $unsigned(r2) ? 1 : 0;
                endcase
            end
            else begin // 10xxx
                case (rs_op_type[2:0])
                    BEQ:  result <= r1 == r2 ? 1 : 0;
                    BNE:  result <= r1 != r2 ? 1 : 0;
                    BLT:  result <= $signed(r1) < $signed(r2) ? 1 : 0;
                    BGE:  result <= $signed(r1) >= $signed(r2) ? 1 : 0;
                    BLTU: result <= $unsigned(r1) < $unsigned(r2) ? 1 : 0;
                    BGEU: result <= $unsigned(r1) >= $unsigned(r2) ? 1 : 0;
                endcase
            end
        end
    end


endmodule //ALU
