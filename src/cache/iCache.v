
module InstuctionCache #(
    parameter SizeBit = `ICACHE_SIZE_BIT
) (
    input wire clk_in,       // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    input  wire          inst_valid,
    input  wire [31 : 0] inst_addr,  // instruction address (the last 1 bit should be 0)
    output reg          inst_ready, // if addr hit
    output reg [31 : 0] inst_res,   // instruction value

    output wire                 q1_valid,
    output wire          [31:0] q1_addr,
    input  wire          [31:0] q1_result,
    input  wire                 q1_ready,

    output wire                 q2_valid,
    output wire          [31:0] q2_addr,
    input  wire          [31:0] q2_result,
    input  wire                 q2_ready,

    input  wire                 rob_clear
);
    //  [31 : 2] = [ 31 ~ SizeBit + 2  : SizeBit + 1 ~ 2]
    localparam SIZE = 1 << SizeBit;
    localparam TagBit = 32 - SizeBit - 2;

    // CACHE DATA
    reg                  valid  [0 : SIZE - 1];
    reg [        31 : 0] value  [0 : SIZE - 1];
    reg [TagBit - 1 : 0] tags   [0 : SIZE - 1];

    wire [31 : 0] addr1 = inst_addr;
    wire [31 : 0] addr2 = inst_addr + 32'd2;

    wire [ TagBit - 1 : 0] tag1 = addr1[31 : SizeBit + 2];
    wire [SizeBit - 1 : 0] idx1 = addr1[SizeBit + 1 : 2];
    // wire                   ofs1 = addr1[1];
    wire [ TagBit - 1 : 0] tag2 = addr2[31 : SizeBit + 2];
    wire [SizeBit - 1 : 0] idx2 = addr2[SizeBit + 1 : 2];
    // wire                   ofs2 = addr2[1];

    /*
    type0: addr1[1:0]=00  addr2[1:0]=10 => idx1 = idx2
        res = value[idx1]
    type1: addr[1:0]=10   addr2[1:0]=00 => idx2 = idx1 + 1
        res =  value[idx2][15:0],value[idx1][31:16]

    */
    wire inst_type = addr1[1:0] == 2'b10;

    wire hit1 = valid[idx1] && tags[idx1] == tag1;
    wire hit2 = valid[idx2] && tags[idx2] == tag2;


    wire [31 : 0] inst_res_next = (inst_type == 0) ? value[idx1] : {value[idx2][15:0], value[idx1][31:16]};

    assign q1_valid = inst_valid && !hit1 && !q1_ready;
    assign q1_addr = (inst_type == 0) ? addr1 : addr1 - 32'd2;

    assign q2_valid = inst_valid && !hit2 && inst_type == 1 && !q2_ready;
    assign q2_addr = (inst_type == 0) ? addr2 + 32'd2: addr2;


    integer i;
    always @(posedge clk_in) begin
        if (rst_in) begin
            for (i = 0; i < SIZE; i = i + 1) begin
                valid[i]  <= 0;
                value[i]  <= 0;
                tags[i] <= 0;
            end
            inst_ready <= 0;
            inst_res <= 0;
        end
        else if (rob_clear) begin
            inst_ready <= 0;
            inst_res <= 0;
        end
        else if (!rdy_in) begin
            // do nothing
        end
        else begin
            inst_ready <= hit1 && hit2;
            inst_res <= inst_res_next;
            if (q1_ready) begin
                valid[idx1] <= 1;
                tags[idx1] <= tag1;
                value[idx1] <= q1_result;
            end

            if (q2_ready) begin
                valid[idx2] <= 1;
                tags[idx2] <= tag2;
                value[idx2] <= q2_result;
            end
        end
    end
endmodule