`include "config.v"

module ReservationStation (
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    input wire rob_clear,     // clear all register

    /// From Decoder (Issue)
    input wire                         inst_valid,      // instruction valid
    input wire [ `RS_TYPE_BIT - 1 : 0] inst_type,       // instruction type
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_rob_idx,    // instruction rob index
    input wire [               31 : 0] inst_r1,         // instruction operand 1
    input wire [               31 : 0] inst_r2,         // instruction operand 2
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_dep1,       // instruction dependency 1
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_dep2,       // instruction dependency 2
    input wire                         inst_has_dep1,   // instruction has dependency 1
    input wire                         inst_has_dep2,   // instruction has dependency 2
    output reg                         full,            // reservation station full

    /// To ALU
    output wire                         alu_valid,      // alu valid
    output wire [               31 : 0] alu_r1,         // alu operand 1
    output wire [               31 : 0] alu_r2,         // alu operand 2
    output wire [ `RS_TYPE_BIT - 1 : 0] alu_op,         // alu operation type
    output wire [`ROB_SIZE_BIT - 1 : 0] alu_rob_idx,    // alu rob index

    /// From ROB Write Back to Update
    input wire                         rob_wb_valid1,   // rob write back valid 1
    input wire [`ROB_SIZE_BIT - 1 : 0] rob_wb_idx1,     // rob write back index
    input wire [               31 : 0] rob_wb_val1,     // rob write back value
    input wire                         rob_wb_valid2,   // rob write back valid 2
    input wire [`ROB_SIZE_BIT - 1 : 0] rob_wb_idx2,     // rob write back index
    input wire [               31 : 0] rob_wb_val2      // rob write back value
);
    // Reservation Station Data
    reg                          busy     [0 : `RS_SIZE - 1];
    reg [ `RS_TYPE_BIT - 1 : 0]  optype   [0 : `RS_SIZE - 1];
    reg [`ROB_SIZE_BIT - 1 : 0]  rob_idx  [0 : `RS_SIZE - 1];
    reg [               31 : 0]  r1       [0 : `RS_SIZE - 1];
    reg [               31 : 0]  r2       [0 : `RS_SIZE - 1];
    reg [`ROB_SIZE_BIT - 1 : 0]  dep1     [0 : `RS_SIZE - 1];
    reg [`ROB_SIZE_BIT - 1 : 0]  dep2     [0 : `RS_SIZE - 1];
    reg                          has_dep1 [0 : `RS_SIZE - 1];
    reg                          has_dep2 [0 : `RS_SIZE - 1];
    reg [ `RS_SIZE_BIT : 0]      size;


    wire                         ready    [0 : `RS_SIZE - 1]; // data is ready, can be executed

    generate
        genvar i;
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            assign ready[i] = busy[i] && (!has_dep1[i] && !has_dep2[i]);
        end
    endgenerate

    wire [`RS_SIZE_BIT - 1 : 0] insert_pos;
    wire [`RS_SIZE_BIT - 1 : 0] exe_pos;
    wire                        executable;

    // get free_pos / exe_pos
    generate
        genvar i;
        wire exe_flag [1 : 2 * `RS_SIZE - 1];
        wire [`RS_SIZE_BIT - 1 : 0] exe_idx[1 : 2 * `RS_SIZE - 1];
        wire free_flag [1 : 2 * `RS_SIZE - 1];
        wire [`RS_SIZE_BIT - 1 : 0] free_idx[1 : 2 * `RS_SIZE - 1];

        // init
        for (i = `RS_SIZE; i < 2 * `RS_SIZE; i = i + 1) begin
            assign exe_flag[i] = ready[i - `RS_SIZE];
            assign exe_idx[i] = i - `RS_SIZE;
            assign free_flag[i] = !busy[i - `RS_SIZE];
            assign free_idx[i] = i - `RS_SIZE;
        end

        // gen
        for (i = 1; i < `RS_SIZE; i = i + 1) begin
            assign exe_flag[i] = exe_flag[i << 1] | exe_flag[i << 1 | 1];
            assign exe_idx[i] = exe_flag[i << 1] ? exe_idx[i << 1] : exe_idx[i << 1 | 1];
            assign free_flag[i] = free_flag[i << 1] | free_flag[i << 1 | 1];
            assign free_idx[i] = free_flag[i << 1] ? free_idx[i << 1] : free_idx[i << 1 | 1];
        end

        assign insert_pos = free_idx[1];
        assign exe_pos = exe_idx[1];
        assign executable = exe_flag[1];
    endgenerate

    // Exe to ALU
    assign alu_valid = executable;
    assign alu_r1 = r1[exe_pos];
    assign alu_r2 = r2[exe_pos];
    assign alu_op = optype[exe_pos];
    assign alu_rob_idx = rob_idx[exe_pos];

    wire next_size = executable && !inst_valid ? size - 1 : (!executable && inst_valid ? size + 1 : size);
    wire next_full = next_size == `RS_SIZE;

    always @(posedge clk_in or posedge rst_in) begin
        if (rst_in || rob_clear) begin
            size <= 0;
            full <= 0;
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i] <= 0;
                optype[i] <= 0;
                rob_idx[i] <= 0;
                r1[i] <= 0;
                r2[i] <= 0;
                dep1[i] <= 0;
                dep2[i] <= 0;
                has_dep1[i] <= 0;
                has_dep2[i] <= 0;
            end
        end
        if (!rdy_in) begin
            // do nothing
        end
        else begin
            size <= next_size;
            full <= next_full;

            // insert
            if (inst_valid) begin
                busy[insert_pos] <= 1;
                optype[insert_pos] <= inst_type;
                rob_idx[insert_pos] <= inst_rob_idx;
                r1[insert_pos] <= !inst_has_dep1 ? inst_r1 : (rob_wb_valid1 && inst_dep1 == rob_wb_idx1 ? rob_wb_val1 : 
                                  (rob_wb_valid2 && inst_dep1 == rob_wb_idx2 ? rob_wb_val2 : 32'b0));
                r2[insert_pos] <= !inst_has_dep2 ? inst_r2 : (rob_wb_valid1 && inst_dep2 == rob_wb_idx1 ? rob_wb_val1 : 
                                  (rob_wb_valid2 && inst_dep2 == rob_wb_idx2 ? rob_wb_val2 : 32'b0));
                dep1[insert_pos] <= inst_dep1;
                dep2[insert_pos] <= inst_dep2;
                has_dep1[insert_pos] <= inst_has_dep1 && !(rob_wb_valid1 && inst_dep1 == rob_wb_idx1) && !(rob_wb_valid2 && inst_dep1 == rob_wb_idx2);
                has_dep2[insert_pos] <= inst_has_dep2 && !(rob_wb_valid1 && inst_dep2 == rob_wb_idx1) && !(rob_wb_valid2 && inst_dep2 == rob_wb_idx2);
            end

            // remove exe busy
            if (executable) begin
                busy[exe_pos] <= 0;
            end

            // update dep
            for (i = 0; i < `RS_SIZE; i = i + 1) begin 
                if (busy[i]) begin
                    if (rob_wb_valid1) begin
                        if (has_dep1[i] && (rob_wb_valid1 && dep1[i] == rob_wb_idx1)) begin
                            r1[i] <= rob_wb_val1;
                            has_dep1[i] <= 0;
                        end
                        if (has_dep2[i] && (rob_wb_valid1 && dep2[i] == rob_wb_idx1)) begin
                            r2[i] <= rob_wb_val1;
                            has_dep2[i] <= 0;
                        end
                    end
                    if (rob_wb_valid2) begin
                        if (has_dep1[i] && (rob_wb_valid2 && dep1[i] == rob_wb_idx2)) begin
                            r1[i] <= rob_wb_val2;
                            has_dep1[i] <= 0;
                        end
                        if (has_dep2[i] && (rob_wb_valid2 && dep2[i] == rob_wb_idx2)) begin
                            r2[i] <= rob_wb_val2;
                            has_dep2[i] <= 0;
                        end
                    end
                end
            end
        end
    end
endmodule //ReservationStation

