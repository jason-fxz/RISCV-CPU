`include "config.v"

module ReorderBuffer (
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in         // ready signal, pause cpu when low

    /// from Decoder (Issue)
    input  wire                         inst_valid,
    input  wire                         inst_ready, // data ready
    input  wire [`ROB_TYPE_BIT - 1 : 0] inst_type,  // ROB work type
    input  wire [               31 : 0] inst_value, // data value (RG) | jump address (BR)
    input  wire [                4 : 0] inst_rd,    // destination register 

    input  wire [               31 : 0] inst_addr,  // instruction address (debug)


    /// to Decoder (Issue)
    input  wire [`ROB_SIZE_BIT - 1 : 0] query_rob_idx1,
    output wire                         query_ready1,
    output wire [               31 : 0] query_value1,
    input  wire [`ROB_SIZE_BIT - 1 : 0] query_rob_idx2,
    output wire                         query_ready2,
    output wire [               31 : 0] query_value2,

    /// from ALU (write back)
    input  wire                         alu_valid,
    input  wire [`ROB_SIZE_BIT - 1 : 0] alu_rob_idx,
    input  wire [               31 : 0] alu_value,

    /// from LSB (load write back)
    input  wire                         lsb_valid,
    input  wire [`ROB_SIZE_BIT - 1 : 0] lsb_rob_idx,
    input  wire [               31 : 0] lsb_value,

    output wire [`ROB_SIZE_BIT - 1 : 0] rob_idx_head,
    output wire [`ROB_SIZE_BIT - 1 : 0] rob_idx_tail,

    /// to RegisterFile
    output wire [                4 : 0] rob_set_idx,
    output wire [               31 : 0] rob_set_reg_val,
    output wire [`ROB_SIZE_BIT - 1 : 0] rob_set_recorder,

    /// for branch predict failed
    output reg          clear, // rob clear
    output reg [31 : 0] next_pc,

);
    localparam ROB_SIZE = `ROB_SIZE;
    localparam TypeRG = `ROB_RG;
    localparam TypeST = `ROB_ST;
    localparam TypeBR = `ROB_BR;

    /// ROB data
    reg                         busy  [0 : ROB_SIZE - 1]; // busy flag
    reg                         ready [0 : ROB_SIZE - 1]; // data ready
    reg [`ROB_TYPE_BIT - 1 : 0] type  [0 : ROB_SIZE - 1]; // work type
    reg [               31 : 0] value [0 : ROB_SIZE - 1]; // data value (RG) | jump address if predict failed (BR)
    reg [                4 : 0] rd    [0 : ROB_SIZE - 1]; // destination register (RG) | if branch (BR)
    // for debug
    reg [               31 : 0] iaddr [0 : ROB_SIZE - 1]; // instruction address

    reg [`ROB_SIZE_BIT - 1 : 0] head, tail;

    assign rob_idx_head = head;
    assign rob_idx_tail = tail;

    // commit
    assign commit_reg_flag = rdy_in && busy[head] && ready[head] && (type[head] == TypeRG);
    assign rob_set_idx = commit_reg_flag ? rd[head] : 0;
    assign rob_set_reg_val = commit_reg_flag ? value[head] : 0;
    assign rob_set_recorder = commit_reg_flag ? head : 0;

    // to Decoder query
    assign query_ready1 = ready[query_rob_idx1] || (alu_valid && alu_rob_idx == query_rob_idx1) 
                        || (lsb_valid && lsb_rob_idx == query_rob_idx1);
    assign query_value1 = ready[query_rob_idx1] ? value[query_rob_idx1] : ((alu_valid && alu_rob_idx == query_rob_idx1) ? alu_value : lsb_value);

    assign query_ready2 = ready[query_rob_idx2] || (alu_valid && alu_rob_idx == query_rob_idx2) 
                        || (lsb_valid && lsb_rob_idx == query_rob_idx2);
    assign query_value2 = ready[query_rob_idx2] ? value[query_rob_idx2] : ((alu_valid && alu_rob_idx == query_rob_idx2) ? alu_value : lsb_value);


    integer i;
    always @(posedge clk_in) begin
        if (rst_in || (clear && rdy_in)) begin
            clear <= 0
            next_pc <= 0
            head <= 0;
            tail <= 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                ready[i] <= 0;
                type[i] <= 0;
                value[i] <= 0;
                rd[i] <= 0;
                iaddr[i] <= 0;
            end
        end
        else if (!rdy_in) begin 
            // do nothing
        end
        else begin
            // write back
            if (alu_valid) begin
                ready[alu_rob_idx] <= 1;
                if (type[alu_rob_idx] == TypeRG) begin
                    value[alu_rob_idx] <= alu_value;
                end
                else if (type[alu_rob_idx] == TypeBR) begin
                    // BR predict0
                    rd[alu_rob_idx] <= {4'b0, alu_value[0]};
                end
            end
            if (lsb_valid) begin
                ready[lsb_rob_idx] <= 1;
                value[lsb_rob_idx] <= lsb_value;
            end
            // commit
            if (busy[head] && ready[head]) begin
                head <= head + 1;
                busy[head] <= 0;
                ready[head] <= 0;
                case (type[head])
                    TypeRG: begin
                        // do nothing, wire to RegisterFile done by RegisterFile
                    end
                    TypeST: begin
                        // do nothing, wire to LSB done by LSB
                    end
                    TypeBR: begin
                        // predict0
                        if (rd[head][0] == 1) begin
                            next_pc <= value[head];
                            clear <= 1;
                        end
                    end
                endcase
            end
            // issue
            if (inst_valid) begin
                tail <= tail + 1;
                busy[tail] <= 1;
                ready[tail] <= inst_ready;
                type[tail] <= inst_type;
                value[tail] <= inst_value;
                rd[tail] <= inst_rd;
                iaddr[tail] <= inst_addr;

                // check not full
                if (head == tail && busy[head] && !ready[head]) begin
                    $display("ERR: ROB full, head=%d, tail=%d", head, tail);
                    $finish;
                end
            end
        end
    end


    
endmodule //Reord
