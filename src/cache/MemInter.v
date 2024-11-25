// memory interface

module MemInter(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
	input  wire                 rdy_in,			// ready signal, pause cpu when low

    // to ram
    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)

    input  wire                 io_buffer_full, // 1 if uart buffer is full (TODO: ignore this first)

    input  wire                 rob_clear,
    
    // inst access
    input  wire                 inst_valid,
    input  wire          [31:0] inst_addr,
    output wire          [31:0] inst_result,
    output wire                 inst_ready,

    // data access
    input  wire                 data_valid,
    input  wire                 data_wr,
    // data_len[2]: 0 for signed / 1 for unsigned
    // data_len[1:0]: 2'b00 Byte / 2'b01 Halfword / 2'b10 Word
    input  wire           [2:0] data_len,
    input  wire          [31:0] data_addr,
    input  wire          [31:0] data_value,
    output wire                 data_ready,
    output wire          [31:0] data_result
);
    wire        mu_valid;
    wire        mu_wr;
    wire [31:0] mu_addr;
    wire  [2:0] mu_len;
    wire [31:0] mu_value;
    wire [31:0] mu_result;
    wire        mu_ready;

    reg   [1:0] state; // 00: idle, 01: inst, 10: data
    localparam IDLE = 2'b00, INST = 2'b01, DATA = 2'b10;

    // assign idle = 

    MemUnit memUnit (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rdy_in(rdy_in),
        .mem_din(mem_din),
        .mem_dout(mem_dout),
        .mem_a(mem_a),
        .mem_wr(mem_wr),
        .io_buffer_full(io_buffer_full),
        .valid(mu_valid),
        .wr(mu_wr),
        .addr(mu_addr),
        .len(mu_len),
        .data_in(mu_value),
        .data_out(mu_result),
        .ready(mu_ready),
        .rob_clear(rob_clear)
    );

    wire  choose_inst = inst_valid && !data_valid;

    // choose data first
    assign mu_valid = inst_valid || data_valid;

    assign mu_wr = (state == IDLE || mu_ready) ? data_valid && data_wr : state == DATA && data_wr;
    assign mu_addr = (state == IDLE || mu_ready) ? (data_valid ? data_addr : inst_addr) : (state == DATA ? data_addr : inst_addr);
    assign mu_len = (state == IDLE || mu_ready) ? (data_valid ? data_len : 3'b010) : (state == DATA ? data_len : 3'b010);
    assign mu_value = data_value;

    // assign mu_addr = !mu_valid ? 0 : (data_valid ? data_addr : inst_addr);
    // assign mu_len = !mu_valid ? 3'b111 : (data_valid ? data_len : 3'b010);
    // assign mu_value = !mu_valid ? 0 : (data_valid ? data_value : 0);


    assign data_result = state == DATA ? mu_result : 0;
    assign data_ready = mu_ready && state == DATA;

    assign inst_result = state == INST ? mu_result : 0;
    assign inst_ready = mu_ready && state == INST;

    always @(posedge clk_in) begin
        if (rst_in) begin
            state <= IDLE;
        end
        else if (rob_clear) begin
            state <= data_valid ? DATA : inst_valid ? INST : IDLE;
        end
        else if (rdy_in) begin
            case(state)
                IDLE: begin
                    if (data_valid) begin
                        state <= DATA;
                    end
                    else if (inst_valid) begin
                        state <= INST;
                    end
                end
                INST: begin
                    if (mu_ready) begin
                        state <= data_valid ? DATA : inst_valid ? INST : IDLE;
                    end
                end
                DATA: begin
                    if (mu_ready) begin
                        state <= data_valid ? DATA : inst_valid ? INST : IDLE;
                    end
                end
            endcase
        end
    end

endmodule