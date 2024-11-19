`include "config.v"

module RegisterFile(
    input wire clk_in,       // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    input wire rob_clear,     // clear all register

    /// From ROB
    // Set register
    input wire [                4 : 0] rob_set_idx,
    input wire [               31 : 0] rob_set_reg_val,
    input wire [`ROB_SIZE_BIT - 1 : 0] rob_set_recorder,
    
    /// From Decorder (Issue)
    // Get Register
    input  wire [                4 : 0] get_idx1,
    output wire [               31 : 0] get_reg_val1,
    output wire                         get_has_dep1,
    output wire [`ROB_SIZE_BIT - 1 : 0] get_recorder1,
    input  wire [                4 : 0] get_idx2,
    output wire [               31 : 0] get_reg_val2,
    output wire                         get_has_dep2,
    output wire [`ROB_SIZE_BIT - 1 : 0] get_recorder2,
    // Set register recorder
    input  wire [                4 : 0] set_reg_recorder_idx,
    input  wire [               31 : 0] set_reg_recorder_val

);
    reg [              31 : 0] regs    [0 : 31];
    reg [`ROB_SIZE_BIT - 1: 0] recorder[0 : 31];
    reg                        has_dep [0 : 31];

    assign get_has_dep1 = has_dep[get_idx1];
    assign get_has_dep2 = has_dep[get_idx2];
    assign get_reg_val1 = regs[get_idx1];
    assign get_reg_val2 = regs[get_idx2];
    assign get_recorder1 = recorder[get_idx1];
    assign get_recorder2 = recorder[get_idx2];

    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 0;
                recorder[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (rob_clear) begin
            for (i = 0; i < 32; i = i + 1) begin
                recorder[i] <= 0;
                has_dep[i] <= 0;
            end
        end
        else begin
            if (rob_set_idx != 0) begin
                regs[rob_set_idx] <= rob_set_reg_val;
                if (set_reg_recorder_idx != rob_set_idx && recorder[rob_set_idx] == rob_set_recorder) begin
                    recorder[rob_set_idx] <= 0;
                    has_dep[rob_set_idx] <= 0;
                end
            end
            if (set_reg_recorder_idx != 0) begin
                recorder[set_reg_recorder_idx] <= set_reg_recorder_val;
                has_dep[set_reg_recorder_idx] <= 1;
            end
        end
        
    end

endmodule //RegisterFile
