// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
    input  wire                 clk_in,            // system clock signal
    input  wire                 rst_in,            // reset signal
    input  wire                 rdy_in,            // ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,           // data input bus
    output wire [ 7:0]          mem_dout,          // data output bus
    output wire [31:0]          mem_a,             // address bus (only 17:0 is used)
    output wire                 mem_wr,            // write/read signal (1 for write)
    
    input  wire                 io_buffer_full,    // 1 if uart buffer is full
    
    output wire [31:0]          dbgreg_dout        // cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    wire                        rob_clear;
    wire [31:0]                 rob_next_pc;


    wire [4:0]                  rob_set_idx;
    wire [31:0]                 rob_set_reg_val;
    wire [`ROB_SIZE_BIT - 1:0]  rob_set_recorder;

    
    // 定义 MemInter 所需的信号
    wire                        mem_inst_valid;
    wire [31:0]                 mem_inst_addr;
    wire [31:0]                 mem_inst_result;
    wire                        mem_inst_ready;
    wire                        mem_data_valid;
    wire                        mem_data_wr;
    wire [2:0]                  mem_data_len;
    wire [31:0]                 mem_data_addr;
    wire [31:0]                 mem_data_value;
    wire                        mem_data_ready;
    wire [31:0]                 mem_data_result;

    wire                        ic_q1_valid;
    wire [31:0]                 ic_q1_addr;
    wire [31:0]                 ic_q1_result;
    wire                        ic_q1_ready;
    wire                        ic_q2_valid;
    wire [31:0]                 ic_q2_addr;
    wire [31:0]                 ic_q2_result;
    wire                        ic_q2_ready;
     wire                        fetcher_inst_valid;
    wire [31:0]                 fetcher_inst_addr;
    wire [31:0]                 fetcher_inst_result;
    wire                        dc_ok;
    wire [31:0]                 dc_next_pc;

    wire [4:0]                  rf_get_idx1;
    wire [31:0]                 rf_get_val1;
    wire                        rf_has_dep1;
    wire [`ROB_SIZE_BIT - 1:0]  rf_get_dep1;
    wire [4:0]                  rf_get_idx2;
    wire [31:0]                 rf_get_val2;
    wire                        rf_has_dep2;
    wire [`ROB_SIZE_BIT - 1:0]  rf_get_dep2;
    wire [4:0]                  rf_set_idx;
    wire [`ROB_SIZE_BIT - 1:0]  rf_set_dep;
    wire [`ROB_SIZE_BIT - 1:0]  query_rob_idx1;
    wire                        query_ready1;
    wire [31:0]                 query_value1;
    wire [`ROB_SIZE_BIT - 1:0]  query_rob_idx2;
    wire                        query_ready2;
    wire [31:0]                 query_value2;
    // wire [`ROB_SIZE_BIT - 1:0]  rob_idx_tail;
    wire                        rob_full;
    // wire                        rob_empty;
    wire                        rob_inst_valid;
    wire                        rob_inst_ready;
    wire [`ROB_TYPE_BIT - 1:0]  rob_inst_type;
    wire [31:0]                 rob_inst_value;
    wire [4:0]                  rob_inst_rd;
    wire [31:0]                 rob_inst_addr;
    wire                        rs_full;
    wire                        rs_inst_valid;
    wire [`RS_TYPE_BIT - 1:0]   rs_inst_type;
    wire [`ROB_SIZE_BIT - 1:0]  rs_inst_rob_idx;
    wire [31:0]                 rs_inst_r1;
    wire [31:0]                 rs_inst_r2;
    wire [`ROB_SIZE_BIT - 1:0]  rs_inst_dep1;
    wire [`ROB_SIZE_BIT - 1:0]  rs_inst_dep2;
    wire                        rs_inst_has_dep1;
    wire                        rs_inst_has_dep2;
    wire                        lsb_full;
    wire                        lsb_inst_valid;
    wire [`LSB_TYPE_BIT - 1:0]  lsb_inst_type;
    wire [`ROB_SIZE_BIT - 1:0]  lsb_inst_rob_idx;
    wire [31:0]                 lsb_inst_r1;
    wire [31:0]                 lsb_inst_r2;
    wire [`ROB_SIZE_BIT - 1:0]  lsb_inst_dep1;
    wire [`ROB_SIZE_BIT - 1:0]  lsb_inst_dep2;
    wire                        lsb_inst_has_dep1;
    wire                        lsb_inst_has_dep2;
    wire [11:0]                 lsb_inst_offset;

    wire                        alu_wb_valid;
    wire [`ROB_SIZE_BIT - 1:0]  alu_wb_rob_idx;
    wire [31:0]                 alu_wb_value;

    wire                        lsb_wb_valid;
    wire [`ROB_SIZE_BIT - 1:0]  lsb_wb_rob_idx;
    wire [31:0]                 lsb_wb_value;


    wire [`ROB_SIZE_BIT - 1:0]  rob_idx_head;
    wire                        rob_head_valid;
    wire                        lsb_st_ok;
    wire [`ROB_SIZE_BIT - 1:0]  rob_idx_tail;

    wire                        rs_alu_valid;
    wire [31:0]                 rs_alu_r1;
    wire [31:0]                 rs_alu_r2;
    wire [`RS_TYPE_BIT - 1:0]   rs_alu_op;
    wire [`ROB_SIZE_BIT - 1:0]  rs_alu_rob_idx;

    RegisterFile register_file (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .rob_clear(rob_clear), 

        // From ROB
        .rob_set_idx(rob_set_idx), 
        .rob_set_reg_val(rob_set_reg_val), 
        .rob_set_recorder(rob_set_recorder), 

        // From Decoder (Issue)
        .get_idx1(rf_get_idx1), 
        .get_reg_val1(rf_get_val1), 
        .get_has_dep1(rf_has_dep1), 
        .get_recorder1(rf_get_dep1), 
        .get_idx2(rf_get_idx2), 
        .get_reg_val2(rf_get_val2), 
        .get_has_dep2(rf_has_dep2), 
        .get_recorder2(rf_get_dep2), 

        // Set register recorder
        .set_reg_recorder_idx(rf_set_idx), 
        .set_reg_recorder_val(rf_set_dep) 
    );

    MemInter mem_inter (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),
        .io_buffer_full(io_buffer_full),
        .rob_clear(rob_clear),

        .inst1_valid(ic_q1_valid),
        .inst1_addr(ic_q1_addr),
        .inst1_result(ic_q1_result),
        .inst1_ready(ic_q1_ready),
        .inst2_valid(ic_q2_valid),
        
        // .inst1_valid(mem_inst_valid),
        // .inst1_addr(mem_inst_addr),
        // .inst1_result(mem_inst_result),
        // .inst1_ready(mem_inst_ready),
        // .inst2_valid(0),
        
        .inst2_addr(ic_q2_addr),
        .inst2_result(ic_q2_result),
        .inst2_ready(ic_q2_ready),
        .data_valid(mem_data_valid),
        .data_wr(mem_data_wr),
        .data_len(mem_data_len),
        .data_addr(mem_data_addr),
        .data_value(mem_data_value),
        .data_ready(mem_data_ready),
        .data_result(mem_data_result)
    );

    InstuctionCache i_cache (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .inst_valid(mem_inst_valid),
        .inst_addr(mem_inst_addr),
        .inst_res(mem_inst_result),
        .inst_ready(mem_inst_ready),
        .q1_valid(ic_q1_valid),
        .q1_addr(ic_q1_addr),
        .q1_result(ic_q1_result),
        .q1_ready(ic_q1_ready),
        .q2_valid(ic_q2_valid),
        .q2_addr(ic_q2_addr),
        .q2_result(ic_q2_result),
        .q2_ready(ic_q2_ready),
        .rob_clear(rob_clear)
    );

    Fetcher fetcher (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .mem_valid(mem_inst_valid),
        .mem_addr(mem_inst_addr),
        .mem_result(mem_inst_result),
        .mem_ready(mem_inst_ready),
        .dc_ok(dc_ok),
        .dc_next_pc(dc_next_pc),
        .inst_valid(fetcher_inst_valid),
        .inst_addr(fetcher_inst_addr),
        .inst_result(fetcher_inst_result),
        .rob_clear(rob_clear),
        .rob_next_pc(rob_next_pc)
    );

   

    DecoderC decoder (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .rob_clear(rob_clear),

        .inst_valid(fetcher_inst_valid),
        .inst_addr(fetcher_inst_addr),
        .inst_data(fetcher_inst_result),
        .f_next_pc(dc_next_pc),
        .f_ok(dc_ok),
        
        .rf_get_idx1(rf_get_idx1),
        .rf_get_val1(rf_get_val1),
        .rf_has_dep1(rf_has_dep1),
        .rf_get_dep1(rf_get_dep1),
        .rf_get_idx2(rf_get_idx2),
        .rf_get_val2(rf_get_val2),
        .rf_has_dep2(rf_has_dep2),
        .rf_get_dep2(rf_get_dep2),
        .rf_set_idx(rf_set_idx),
        .rf_set_dep(rf_set_dep),

        .query_rob_idx1(query_rob_idx1),
        .query_ready1(query_ready1),
        .query_value1(query_value1),
        .query_rob_idx2(query_rob_idx2),
        .query_ready2(query_ready2),
        .query_value2(query_value2),

        .rob_idx_tail(rob_idx_tail),
        .rob_full(rob_full),
        // .rob_empty(rob_empty),
        .rob_inst_valid(rob_inst_valid),
        .rob_inst_ready(rob_inst_ready),
        .rob_inst_type(rob_inst_type),
        .rob_inst_value(rob_inst_value),
        .rob_inst_rd(rob_inst_rd),
        .rob_inst_addr(rob_inst_addr),
        
        .rs_full(rs_full),
        .rs_inst_valid(rs_inst_valid),
        .rs_inst_type(rs_inst_type),
        .rs_inst_rob_idx(rs_inst_rob_idx),
        .rs_inst_r1(rs_inst_r1),
        .rs_inst_r2(rs_inst_r2),
        .rs_inst_dep1(rs_inst_dep1),
        .rs_inst_dep2(rs_inst_dep2),
        .rs_inst_has_dep1(rs_inst_has_dep1),
        .rs_inst_has_dep2(rs_inst_has_dep2),
        
        .lsb_full(lsb_full),
        .lsb_inst_valid(lsb_inst_valid),
        .lsb_inst_type(lsb_inst_type),
        .lsb_inst_rob_idx(lsb_inst_rob_idx),
        .lsb_inst_r1(lsb_inst_r1),
        .lsb_inst_r2(lsb_inst_r2),
        .lsb_inst_dep1(lsb_inst_dep1),
        .lsb_inst_dep2(lsb_inst_dep2),
        .lsb_inst_has_dep1(lsb_inst_has_dep1),
        .lsb_inst_has_dep2(lsb_inst_has_dep2),
        .lsb_inst_offset(lsb_inst_offset)
    );

    ReorderBuffer reorder_buffer (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        // from Decoder (Issue)
        .inst_valid(rob_inst_valid),
        .inst_ready(rob_inst_ready), 
        .inst_type(rob_inst_type),
        .inst_value(rob_inst_value), 
        .inst_rd(rob_inst_rd),       
        .full(rob_full),
        .inst_addr(rob_inst_addr),

        // to Decoder (Issue)
        .query_rob_idx1(query_rob_idx1),
        .query_ready1(query_ready1),
        .query_value1(query_value1),
        .query_rob_idx2(query_rob_idx2),
        .query_ready2(query_ready2),
        .query_value2(query_value2),

        // from ALU (write back)
        .alu_valid(alu_wb_valid),
        .alu_rob_idx(alu_wb_rob_idx),
        .alu_value(alu_wb_value),

        // from LSB (load write back)
        .lsb_valid(lsb_wb_valid),
        .lsb_rob_idx(lsb_wb_rob_idx),
        .lsb_value(lsb_wb_value),

        .rob_idx_head(rob_idx_head),
        .rob_head_valid(rob_head_valid),
        .lsb_st_ok(lsb_st_ok),
        .rob_idx_tail(rob_idx_tail),

        // to RegisterFile
        .rob_set_idx(rob_set_idx),
        .rob_set_reg_val(rob_set_reg_val), 
        .rob_set_recorder(rob_set_recorder), 

        // for branch predict failed
        .clear(rob_clear),
        .next_pc(rob_next_pc)
    );

    

    
    ReservationStation reservation_station (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .rob_clear(rob_clear),

        // From Decoder (Issue)
        .inst_valid(rs_inst_valid),
        .inst_type(rs_inst_type),
        .inst_rob_idx(rs_inst_rob_idx),
        .inst_r1(rs_inst_r1),
        .inst_r2(rs_inst_r2),
        .inst_dep1(rs_inst_dep1),
        .inst_dep2(rs_inst_dep2),
        .inst_has_dep1(rs_inst_has_dep1),
        .inst_has_dep2(rs_inst_has_dep2),
        .full(rs_full),

        // To ALU
        .alu_valid(rs_alu_valid),
        .alu_r1(rs_alu_r1),
        .alu_r2(rs_alu_r2),
        .alu_op(rs_alu_op),
        .alu_rob_idx(rs_alu_rob_idx),

        // From ROB Write Back to Update
        .alu_wb_valid(alu_wb_valid),
        .alu_wb_idx(alu_wb_rob_idx),
        .alu_wb_value(alu_wb_value),
        .lsb_wb_valid(lsb_wb_valid),
        .lsb_wb_idx(lsb_wb_rob_idx),
        .lsb_wb_value(lsb_wb_value)
    );

    LoadStoreBuffer load_store_buffer (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),

        .rob_clear(rob_clear),

        // From Decoder (Issue)
        .inst_valid(lsb_inst_valid),
        .inst_type(lsb_inst_type),
        .inst_rob_idx(lsb_inst_rob_idx),
        .inst_r1(lsb_inst_r1),
        .inst_r2(lsb_inst_r2),
        .inst_dep1(lsb_inst_dep1),
        .inst_dep2(lsb_inst_dep2),
        .inst_has_dep1(lsb_inst_has_dep1),
        .inst_has_dep2(lsb_inst_has_dep2),
        .inst_offset(lsb_inst_offset),
        .full(lsb_full),

        // From ROB check Store commit
        .rob_head_valid(rob_head_valid),
        .rob_head_id(rob_idx_head),
        .rob_st_ok(lsb_st_ok),

        // From Write Back to Update
        .alu_wb_valid(alu_wb_valid),
        .alu_wb_idx(alu_wb_rob_idx),
        .alu_wb_value(alu_wb_value),
        .lsb_wb_valid(lsb_wb_valid),
        .lsb_wb_idx(lsb_wb_rob_idx),
        .lsb_wb_value(lsb_wb_value),

        // To MemInter
        .mem_valid(mem_data_valid),
        .mem_wr(mem_data_wr),
        .mem_len(mem_data_len),
        .mem_addr(mem_data_addr),
        .mem_value(mem_data_value),
        .mem_ready(mem_data_ready),
        .mem_result(mem_data_result)
    );

    ALU alu (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .rob_clear(rob_clear),

        // from reservation station
        .valid(rs_alu_valid),
        .r1(rs_alu_r1),
        .r2(rs_alu_r2),
        .rob_idx_in(rs_alu_rob_idx),
        .rs_op_type(rs_alu_op),

        // to ROB
        .result(alu_wb_value),
        .rob_idx(alu_wb_rob_idx),
        .ready(alu_wb_valid)
    );



endmodule