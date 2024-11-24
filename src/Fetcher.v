`include "config.v"

module Fetcher(
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    // to Mem
    output wire           mem_valid,
    output wire  [31 : 0] mem_addr,
    input  wire  [31 : 0] mem_result,
    input  wire           mem_ready,

    // to Decoder
    input  wire           dc_ok,
    input  wire  [31 : 0] dc_next_pc,
    output wire           inst_valid,
    output wire  [31 : 0] inst_addr,
    output wire  [31 : 0] inst_result,

    // rob clear
    input  wire           rob_clear,
    input  wire  [31 : 0] rob_next_pc
);

    reg [31 : 0] PC;
    reg  enable_fetch;

    reg [31 : 0] tmp_inst_addr;
    reg [31 : 0] tmp_inst_result;
    reg          tmp_inst_valid;

    assign mem_valid = enable_fetch;
    assign mem_addr = PC;



    assign inst_valid = mem_ready || tmp_inst_valid;
    assign inst_result = mem_ready ? mem_result : tmp_inst_result;
    assign inst_addr = PC;


    wire [31 : 0] next_pc = rob_clear ? rob_next_pc : dc_next_pc;


    always @(posedge clk_in) begin
        if (rst_in) begin
            PC <= 0;
            enable_fetch <= 1;
            tmp_inst_addr <= 0;
            tmp_inst_result <= 0;
            tmp_inst_valid <= 0;
        end
        else if (!rdy_in) begin 
            // do nothing
        end
        else if (rob_clear) begin
            PC <= next_pc;
            enable_fetch <= 1;
            tmp_inst_addr <= 0;
            tmp_inst_result <= 0;
            tmp_inst_valid <= 0;
        end
        else begin
            // fetch ok
            if (mem_ready) begin
                tmp_inst_valid <= 1;
                tmp_inst_addr <= PC;
                tmp_inst_result <= mem_result;
                enable_fetch <= 0;
            end
            // decoder get next
            if (dc_ok) begin
                PC <= next_pc;
                enable_fetch <= 1;
                tmp_inst_addr <= 0;
                tmp_inst_result <= 0;
                tmp_inst_valid <= 0;
            end
        end
    end
    
endmodule //Fetcher
