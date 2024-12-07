`include "config.v"

module Decoder(
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    input wire rob_clear,

    // from fetcher
    input wire                           inst_valid,
    input wire [                 31 : 0] inst_addr,
    input wire [                 31 : 0] inst_data,
    // to fetcher
    output wire [                31 : 0] f_next_pc,
    output wire                          f_ok,

    /// to RegisterFile
    output wire [                 4 : 0] rf_get_idx1,
    input  wire [                31 : 0] rf_get_val1,
    input  wire                          rf_has_dep1,
    input  wire [ `ROB_SIZE_BIT - 1 : 0] rf_get_dep1,
    output wire [                 4 : 0] rf_get_idx2,
    input  wire [                31 : 0] rf_get_val2,
    input  wire                          rf_has_dep2,
    input  wire [ `ROB_SIZE_BIT - 1 : 0] rf_get_dep2,

    output reg  [                 4 : 0] rf_set_idx,
    output wire [ `ROB_SIZE_BIT - 1 : 0] rf_set_dep,

    /// query ROB for dependency
    output wire  [`ROB_SIZE_BIT - 1 : 0] query_rob_idx1,
    input  wire                          query_ready1,
    input  wire  [               31 : 0] query_value1,
    output wire  [`ROB_SIZE_BIT - 1 : 0] query_rob_idx2,
    input  wire                          query_ready2,
    input  wire  [               31 : 0] query_value2,

    /// to ReorderBuffer
    input  wire [ `ROB_SIZE_BIT - 1 : 0] rob_idx_tail,
    input  wire                          rob_full,
    // input  wire                          rob_empty,
    output reg                           rob_inst_valid,
    output reg                           rob_inst_ready, // data ready
    output reg  [ `ROB_TYPE_BIT - 1 : 0] rob_inst_type,  // ROB work type
    output reg  [                31 : 0] rob_inst_value, // data value (RG) | jump address (BR)
    output reg  [                 4 : 0] rob_inst_rd,    // destination register
    output reg  [                31 : 0] rob_inst_addr,  // instruction address (debug)


    /// to ReservationStation
    input  wire                          rs_full,
    output reg                           rs_inst_valid,
    output reg  [  `RS_TYPE_BIT - 1 : 0] rs_inst_type,
    output wire [ `ROB_SIZE_BIT - 1 : 0] rs_inst_rob_idx,
    output wire [                31 : 0] rs_inst_r1,
    output wire [                31 : 0] rs_inst_r2,
    output wire [ `ROB_SIZE_BIT - 1 : 0] rs_inst_dep1,
    output wire [ `ROB_SIZE_BIT - 1 : 0] rs_inst_dep2,
    output wire                          rs_inst_has_dep1,
    output wire                          rs_inst_has_dep2,


    /// to LoadStoreBuffer
    input  wire                         lsb_full,
    output reg                          lsb_inst_valid,
    output reg [ `LSB_TYPE_BIT - 1 : 0] lsb_inst_type,
    output wire[ `ROB_SIZE_BIT - 1 : 0] lsb_inst_rob_idx,
    output wire[                31 : 0] lsb_inst_r1,
    output wire[                31 : 0] lsb_inst_r2,
    output wire[ `ROB_SIZE_BIT - 1 : 0] lsb_inst_dep1,
    output wire[ `ROB_SIZE_BIT - 1 : 0] lsb_inst_dep2,
    output wire                         lsb_inst_has_dep1,
    output wire                         lsb_inst_has_dep2,
    output reg [                11 : 0] lsb_inst_offset

);
    localparam OpcArithR = 7'b0110011;
    localparam OpcArithI = 7'b0010011;
    localparam OpcLoad   = 7'b0000011;
    localparam OpcStore  = 7'b0100011;
    localparam OpcBranch = 7'b1100011;
    localparam OpcJAL    = 7'b1101111;
    localparam OpcJALR   = 7'b1100111;
    localparam OpcAUIPC  = 7'b0010111;
    localparam OpcLUI    = 7'b0110111;

    wire [6 : 0] opcode = inst_data[6 : 0];
    wire [4 : 0] rd = inst_data[11 : 7];
    wire [4 : 0] rs1 = inst_data[19 : 15];
    wire [4 : 0] rs2 = inst_data[24 : 20];
    wire [2 : 0] funct3 = inst_data[14 : 12];
    wire [6 : 0] funct7 = inst_data[31 : 25];

    wire [11 : 0] immI = inst_data[31 : 20];
    wire [ 4 : 0] immIs = inst_data[24 : 20];
    wire [11 : 0] immS = {inst_data[31 : 25], inst_data[11 : 7]};
    wire [12 : 1] immB = {inst_data[31], inst_data[7], inst_data[30 : 25], inst_data[11 : 8]};
    wire [31 : 12] immU = {inst_data[31 : 12]};
    wire [20 : 1] immJ = {inst_data[31], inst_data[19 : 12], inst_data[20], inst_data[30 : 21]};

    reg [31 : 0] last_inst_addr;
    wire need_work, need_rob, need_rs, need_lsb, could_work;
    wire use_rs1, use_rs2, use_rd;
    wire [31 : 0] next_addr;
    wire [31 : 0] jalr_addr;
    wire [31 : 0] jal_addr;
    wire [31 : 0] br_addr;

    wire has_dep1, has_dep2;
    wire [31 : 0] r1_val;
    wire [31 : 0] r2_val;

    assign need_work = inst_valid && (last_inst_addr != inst_addr);
    assign need_rob = 1'b1;
    assign need_rs = opcode == OpcArithR || opcode == OpcArithI  || opcode == OpcBranch;
    assign need_lsb = opcode == OpcLoad || opcode == OpcStore;
    assign could_work = (!need_rob || !rob_full) && (!need_rs || !rs_full) && (!need_lsb || !lsb_full) && (opcode != OpcJALR || !has_dep1);

    assign next_addr = inst_addr + 32'd4;
    assign jalr_addr = r1_val + {{20{immI[11]}}, immI[10:0]};
    assign jal_addr  = inst_addr + {{11{immJ[20]}}, immJ, 1'b0};
    assign br_addr   = inst_addr + {{19{immB[12]}}, immB, 1'b0};

    assign f_ok = need_work && could_work;
    assign f_next_pc = opcode == OpcJALR ? jalr_addr : 
                       opcode == OpcJAL ? jal_addr :
                       next_addr;

    assign use_rs1 = opcode == OpcArithR || opcode == OpcArithI || opcode == OpcLoad || opcode == OpcStore || opcode == OpcBranch || opcode == OpcJALR;
    assign use_rs2 = opcode == OpcArithR || opcode == OpcStore || opcode == OpcBranch;
    assign use_rd = opcode == OpcArithR || opcode == OpcArithI || opcode == OpcLoad || opcode == OpcJALR || opcode == OpcJAL || opcode == OpcLUI || opcode == OpcAUIPC;



    // dependency check
    assign rf_get_idx1 = rs1;
    assign rf_get_idx2 = rs2;
    assign query_rob_idx1 = rf_get_dep1;
    assign query_rob_idx2 = rf_get_dep2;

    assign has_dep1 = rf_has_dep1 && !query_ready1;
    assign has_dep2 = rf_has_dep2 && !query_ready2;
    assign r1_val = !rf_has_dep1 ? rf_get_val1 : (query_ready1 ? query_value1 : 0);
    assign r2_val = !rf_has_dep2 ? rf_get_val2 : (query_ready2 ? query_value2 : 0);

    // for decode result
    reg [               31 : 0] inst_r1, inst_r2;
    reg                         inst_has_dep1, inst_has_dep2;
    reg [`ROB_SIZE_BIT - 1 : 0] inst_dep1, inst_dep2;


    always @(posedge clk_in) begin
        if (rst_in || rob_clear) begin
            rs_inst_valid <= 0;
            rs_inst_type <= 0;
            
            lsb_inst_valid <= 0;
            lsb_inst_type <= 0;
            lsb_inst_offset <= 0;

            inst_r1 <= 0;
            inst_r2 <= 0;
            inst_has_dep1 <= 0;
            inst_has_dep2 <= 0;
            inst_dep1 <= 0;
            inst_dep2 <= 0;

            last_inst_addr <= 32'hffffffff;

            rob_inst_valid <= 0;
            rob_inst_ready <= 0;
            rob_inst_type <= 0;
            rob_inst_value <= 0;
            rob_inst_rd <= 0;
            rob_inst_addr <= 0;
            rf_set_idx <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else if (!f_ok) begin
            rob_inst_valid <= 0;
            rs_inst_valid <= 0;
            lsb_inst_valid <= 0;
            rf_set_idx <= 0;
        end
        else begin
            // $display("Decode %h:[%h] time:%0t opcode=%h",inst_addr, inst_data, $time, opcode);
            last_inst_addr <= inst_addr;

            rob_inst_valid <= need_rob;
            rob_inst_type <= opcode == OpcStore ? `ROB_ST : 
                        opcode == OpcBranch ? `ROB_BR : `ROB_RG;
            
            rob_inst_rd <= use_rd ? rd : 0;
            rob_inst_addr <= inst_addr;
// rob_inst_value, 
            
            inst_r1 <= r1_val;
            inst_r2 <= opcode == OpcArithI ? ((funct3 == 3'b001 || funct3 == 3'b101) ? immIs : {{20{immI[11]}}, immI}) : r2_val;
            inst_has_dep1 <= use_rs1 && has_dep1;
            inst_has_dep2 <= use_rs2 && has_dep2;
            inst_dep1 <= rf_get_dep1;
            inst_dep2 <= rf_get_dep2;

            rs_inst_valid <= need_rs;
            rs_inst_type <= {(opcode == OpcBranch), opcode == OpcArithR && funct7[5], funct3};

            lsb_inst_valid <= need_lsb;
            lsb_inst_type <= {opcode == OpcStore, funct3};
            lsb_inst_offset <= opcode == OpcLoad ? immI : immS;

            rob_inst_ready <= opcode == OpcLUI || opcode == OpcAUIPC || opcode == OpcJAL || opcode == OpcJALR || opcode == OpcStore;
            rob_inst_value <= opcode == OpcLUI ? {immU, 12'b0} :
                              opcode == OpcAUIPC ? inst_addr + {immU, 12'b0} :
                              opcode == OpcJAL ? next_addr :
                              opcode == OpcJALR ? next_addr :
                              opcode == OpcBranch ? br_addr : 0;
            
            rf_set_idx <= use_rd ? rd : 0;
        end
        
    end


    assign rs_inst_r1 = inst_r1;
    assign rs_inst_r2 = inst_r2;
    assign rs_inst_has_dep1 = inst_has_dep1;
    assign rs_inst_has_dep2 = inst_has_dep2;
    assign rs_inst_dep1 = inst_dep1;
    assign rs_inst_dep2 = inst_dep2;
    assign rs_inst_rob_idx = rob_idx_tail;

    assign lsb_inst_r1 = inst_r1;
    assign lsb_inst_r2 = inst_r2;
    assign lsb_inst_has_dep1 = inst_has_dep1;
    assign lsb_inst_has_dep2 = inst_has_dep2;
    assign lsb_inst_dep1 = inst_dep1;
    assign lsb_inst_dep2 = inst_dep2;
    assign lsb_inst_rob_idx = rob_idx_tail;

    assign rf_set_dep = rob_idx_tail;
    // assign rf_set_idx = (f_ok && use_rd) ? rd : 0;

    
endmodule //Decoder
