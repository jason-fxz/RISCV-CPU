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
    input  wire [`ROB_SIZE_BIT - 1 : 0] set_reg_recorder_val

);
    reg [              31 : 0] regs    [0 : 31];
    reg [`ROB_SIZE_BIT - 1: 0] recorder[0 : 31];
    reg                        has_dep [0 : 31];

    assign get_has_dep1 = has_dep[get_idx1] || (set_reg_recorder_idx && set_reg_recorder_idx == get_idx1);
    assign get_has_dep2 = has_dep[get_idx2] || (set_reg_recorder_idx && set_reg_recorder_idx == get_idx2);
    assign get_reg_val1 = regs[get_idx1];
    assign get_reg_val2 = regs[get_idx2];
    assign get_recorder1 = (set_reg_recorder_idx && set_reg_recorder_idx == get_idx1) ? set_reg_recorder_val : recorder[get_idx1];
    assign get_recorder2 = (set_reg_recorder_idx && set_reg_recorder_idx == get_idx2) ? set_reg_recorder_val : recorder[get_idx2];

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

    // for debug
    wire [31 : 0] reg_zero = regs[0];  // 00
    wire [31 : 0] reg_ra = regs[1];    // 01
    wire [31 : 0] reg_sp = regs[2];    // 02
    wire [31 : 0] reg_gp = regs[3];    // 03
    wire [31 : 0] reg_tp = regs[4];    // 04
    wire [31 : 0] reg_t0 = regs[5];    // 05
    wire [31 : 0] reg_t1 = regs[6];    // 06
    wire [31 : 0] reg_t2 = regs[7];    // 07
    wire [31 : 0] reg_s0 = regs[8];    // 08
    wire [31 : 0] reg_s1 = regs[9];    // 09
    wire [31 : 0] reg_a0 = regs[10];   // 0A
    wire [31 : 0] reg_a1 = regs[11];   // 0B
    wire [31 : 0] reg_a2 = regs[12];   // 0C
    wire [31 : 0] reg_a3 = regs[13];   // 0D
    wire [31 : 0] reg_a4 = regs[14];   // 0E
    wire [31 : 0] reg_a5 = regs[15];   // 0F
    wire [31 : 0] reg_a6 = regs[16];   // 10
    wire [31 : 0] reg_a7 = regs[17];   // 11
    wire [31 : 0] reg_s2 = regs[18];   // 12
    wire [31 : 0] reg_s3 = regs[19];   // 13
    wire [31 : 0] reg_s4 = regs[20];   // 14
    wire [31 : 0] reg_s5 = regs[21];   // 15
    wire [31 : 0] reg_s6 = regs[22];   // 16
    wire [31 : 0] reg_s7 = regs[23];   // 17
    wire [31 : 0] reg_s8 = regs[24];   // 18
    wire [31 : 0] reg_s9 = regs[25];   // 19
    wire [31 : 0] reg_s10 = regs[26];  // 1A
    wire [31 : 0] reg_s11 = regs[27];  // 1B
    wire [31 : 0] reg_t3 = regs[28];   // 1C
    wire [31 : 0] reg_t4 = regs[29];   // 1D
    wire [31 : 0] reg_t5 = regs[30];   // 1E
    wire [31 : 0] reg_t6 = regs[31];   // 1F

    wire [`ROB_SIZE_BIT - 1: 0] reg_zero_r = recorder[0];
    wire [`ROB_SIZE_BIT - 1: 0] reg_ra_r = recorder[1];
    wire [`ROB_SIZE_BIT - 1: 0] reg_sp_r = recorder[2];
    wire [`ROB_SIZE_BIT - 1: 0] reg_gp_r = recorder[3];
    wire [`ROB_SIZE_BIT - 1: 0] reg_tp_r = recorder[4];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t0_r = recorder[5];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t1_r = recorder[6];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t2_r = recorder[7];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s0_r = recorder[8];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s1_r = recorder[9];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a0_r = recorder[10];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a1_r = recorder[11];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a2_r = recorder[12];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a3_r = recorder[13];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a4_r = recorder[14];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a5_r = recorder[15];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a6_r = recorder[16];
    wire [`ROB_SIZE_BIT - 1: 0] reg_a7_r = recorder[17];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s2_r = recorder[18];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s3_r = recorder[19];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s4_r = recorder[20];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s5_r = recorder[21];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s6_r = recorder[22];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s7_r = recorder[23];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s8_r = recorder[24];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s9_r = recorder[25];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s10_r = recorder[26];
    wire [`ROB_SIZE_BIT - 1: 0] reg_s11_r = recorder[27];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t3_r = recorder[28];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t4_r = recorder[29];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t5_r = recorder[30];
    wire [`ROB_SIZE_BIT - 1: 0] reg_t6_r = recorder[31];

    wire reg_zero_h = has_dep[0];
    wire reg_ra_h = has_dep[1];
    wire reg_sp_h = has_dep[2];
    wire reg_gp_h = has_dep[3];
    wire reg_tp_h = has_dep[4];
    wire reg_t0_h = has_dep[5];
    wire reg_t1_h = has_dep[6];
    wire reg_t2_h = has_dep[7];
    wire reg_s0_h = has_dep[8];
    wire reg_s1_h = has_dep[9];
    wire reg_a0_h = has_dep[10];
    wire reg_a1_h = has_dep[11];
    wire reg_a2_h = has_dep[12];
    wire reg_a3_h = has_dep[13];
    wire reg_a4_h = has_dep[14];
    wire reg_a5_h = has_dep[15];
    wire reg_a6_h = has_dep[16];
    wire reg_a7_h = has_dep[17];
    wire reg_s2_h = has_dep[18];
    wire reg_s3_h = has_dep[19];
    wire reg_s4_h = has_dep[20];
    wire reg_s5_h = has_dep[21];
    wire reg_s6_h = has_dep[22];
    wire reg_s7_h = has_dep[23];
    wire reg_s8_h = has_dep[24];
    wire reg_s9_h = has_dep[25];
    wire reg_s10_h = has_dep[26];
    wire reg_s11_h = has_dep[27];
    wire reg_t3_h = has_dep[28];
    wire reg_t4_h = has_dep[29];
    wire reg_t5_h = has_dep[30];
    wire reg_t6_h = has_dep[31];



endmodule //RegisterFile
