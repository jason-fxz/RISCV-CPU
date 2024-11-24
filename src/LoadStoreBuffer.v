`include "config.v"

module LoadStoreBuffer (
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,         // ready signal, pause cpu when low

    input wire rob_clear,

    /// from Decoder (Issue)
    input wire                         inst_valid,
    input wire [`LSB_TYPE_BIT - 1 : 0] inst_type,
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_rob_idx,    // instruction rob index
    input wire [               31 : 0] inst_r1,         // instruction operand 1
    input wire [               31 : 0] inst_r2,         // instruction operand 2
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_dep1,       // instruction dependency 1
    input wire [`ROB_SIZE_BIT - 1 : 0] inst_dep2,       // instruction dependency 2
    input wire                         inst_has_dep1,   // instruction has dependency 1
    input wire                         inst_has_dep2,   // instruction has dependency 2
    input wire [               11 : 0] inst_offset,     // instruction offset
    output reg                         full,            // reservation station full

    /// from ROB check Store commit
    input wire                         rob_head_valid,
    input wire [`ROB_SIZE_BIT - 1 : 0] rob_head_id,
    output wire                        rob_st_ok,
    

    /// From Write Back to Update
    input wire                         alu_wb_valid,    // alu write back valid
    input wire [`ROB_SIZE_BIT - 1 : 0] alu_wb_idx,      // alu write back rob_index
    input wire [               31 : 0] alu_wb_value,    // alu write back value
    
    output wire                         lsb_wb_valid,    // lsb write back valid
    output wire [`ROB_SIZE_BIT - 1 : 0] lsb_wb_idx,      // lsb write back rob_index
    output wire [               31 : 0] lsb_wb_value,     // lsb write back value

    /// to MemInter
    output wire                        mem_valid,
    output wire                        mem_wr,
    output wire [2:0]                  mem_len,
    output wire [31:0]                 mem_addr,
    output wire [31:0]                 mem_value,
    input wire                         mem_ready,
    input wire [31:0]                  mem_result
    
);
    localparam LSB_SIZE = `LSB_SIZE;
    

    /// LSB data
    reg                         busy    [0 : LSB_SIZE - 1]; // busy flag
    reg [`ROB_SIZE_BIT - 1 : 0] rob_idx [0 : LSB_SIZE - 1]; // rob index
    reg [`LSB_TYPE_BIT - 1 : 0] type    [0 : LSB_SIZE - 1]; // work type
    reg [               31 : 0] r1      [0 : LSB_SIZE - 1]; // operand 1
    reg [               31 : 0] r2      [0 : LSB_SIZE - 1]; // operand 2
    reg [`ROB_SIZE_BIT - 1 : 0] dep1    [0 : LSB_SIZE - 1]; // dependency 1
    reg [`ROB_SIZE_BIT - 1 : 0] dep2    [0 : LSB_SIZE - 1]; // dependency 2 
    reg                         has_dep1[0 : LSB_SIZE - 1]; // has dependency 1
    reg                         has_dep2[0 : LSB_SIZE - 1]; // has dependency 2
    reg [               11 : 0] offset  [0 : LSB_SIZE - 1]; // offset
    

    wire                        ready   [0 : LSB_SIZE - 1]; // data is ready, can be executed

    reg [     `LSB_SIZE_BIT : 0] size;
    reg [ `LSB_SIZE_BIT - 1 : 0] head, tail; // [head, tail)
    
    generate
        genvar i;
        for (i = 0; i < LSB_SIZE; i = i + 1) begin
            assign ready[i] = busy[i] && (!has_dep1[i] && !has_dep2[i]);
        end
    endgenerate

    wire pop_head = mem_ready;
    wire [`LSB_SIZE_BIT : 0] next_size = pop_head && !inst_valid ? size - 1 : (!pop_head && inst_valid ? size + 1 : size);
    wire next_full = next_size == LSB_SIZE;

    assign lsb_wb_valid = mem_ready && busy[head] && type[head][3] == 1'b0;
    assign lsb_wb_idx = rob_idx[head];
    assign lsb_wb_value = mem_result;

    // load can be easily valid / store should be valid when rob commit
    wire [`LSB_SIZE_BIT - 1 : 0] head_k = mem_ready ? head + 1 : head;
    
    assign mem_valid = busy[head_k] && (type[head_k][3] != 1 || rob_head_valid && rob_head_id == rob_idx[head_k]);
    assign mem_wr = type[head_k][3];
    assign mem_len = type[head_k][2:0];
    assign mem_addr = r1[head_k] + {{20{offset[head_k][11]}}, offset[head_k]};
    assign mem_value = r2[head_k];

    assign rob_st_ok = mem_ready;

    always @(posedge clk_in) begin : Main
        integer i;
        if (rst_in || rob_clear) begin
            size <= 0;
            full <= 0;
            head <= 0;
            tail <= 0;
            for (i = 0; i < LSB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                rob_idx[i] <= 0;
                type[i] <= 0;
                r1[i] <= 0;
                r2[i] <= 0;
                dep1[i] <= 0;
                dep2[i] <= 0;
                has_dep1[i] <= 0;
                has_dep2[i] <= 0;
                offset[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            size <= next_size;
            full <= next_full;

            // issue (push)
            if (inst_valid) begin
                tail <= tail + 1;
                busy[tail] <= 1;
                type[tail] <= inst_type;
                rob_idx[tail] <= inst_rob_idx;
                dep1[tail] <= inst_dep1;
                dep2[tail] <= inst_dep2;
                r1[tail] <= !inst_has_dep1 ? inst_r1 :  (alu_wb_valid && inst_dep1 == alu_wb_idx ? alu_wb_value : 
                                  (lsb_wb_valid && inst_dep1 == lsb_wb_idx ? lsb_wb_value : 32'b0));
                r2[tail] <= !inst_has_dep2 ? inst_r2 :  (alu_wb_valid && inst_dep2 == alu_wb_idx ? alu_wb_value : 
                                  (lsb_wb_valid && inst_dep2 == lsb_wb_idx ? lsb_wb_value : 32'b0));
                has_dep1[tail] <= inst_has_dep1 && !(alu_wb_valid && inst_dep1 == alu_wb_idx) && !(lsb_wb_valid && inst_dep1 == lsb_wb_idx);
                has_dep2[tail] <= inst_has_dep2 && !(alu_wb_valid && inst_dep2 == alu_wb_idx) && !(lsb_wb_valid && inst_dep2 == lsb_wb_idx);
                offset[tail] <= inst_offset;
            end

            // remove head
            if (pop_head) begin
                head <= head + 1;
                busy[head] <= 0;
            end

            // update dep
            for (i = 0; i < LSB_SIZE; i = i + 1) begin 
                if (busy[i]) begin
                    if (alu_wb_valid) begin
                        if (has_dep1[i] && (alu_wb_valid && dep1[i] == alu_wb_idx)) begin
                            r1[i] <= alu_wb_value;
                            has_dep1[i] <= 0;
                        end
                        if (has_dep2[i] && (alu_wb_valid && dep2[i] == alu_wb_idx)) begin
                            r2[i] <= alu_wb_value;
                            has_dep2[i] <= 0;
                        end
                    end
                    if (lsb_wb_valid) begin
                        if (has_dep1[i] && (lsb_wb_valid && dep1[i] == lsb_wb_idx)) begin
                            r1[i] <= lsb_wb_value;
                            has_dep1[i] <= 0;
                        end
                        if (has_dep2[i] && (lsb_wb_valid && dep2[i] == lsb_wb_idx)) begin
                            r2[i] <= lsb_wb_value;
                            has_dep2[i] <= 0;
                        end
                    end
                end
            end
        end
    end
    
endmodule
