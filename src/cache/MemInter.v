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
    input  wire                 inst1_valid,
    input  wire          [31:0] inst1_addr,
    output wire          [31:0] inst1_result,
    output wire                 inst1_ready,

    input  wire                 inst2_valid,
    input  wire          [31:0] inst2_addr,
    output wire          [31:0] inst2_result,
    output wire                 inst2_ready,

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

    reg   [1:0] state; // 00: idle, 01: data 10: inst1 11: inst2
    localparam IDLE = 2'b00, INST1 = 2'b10, INST2 = 2'b11, DATA = 2'b01;
    // DATA > INST1 > INST2

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

    wire new_work = state == IDLE || mu_ready;

    assign mu_valid = inst1_valid || inst2_valid || data_valid;
    assign mu_wr = new_work ? (data_valid && data_wr) : (state == DATA && data_wr);
    assign mu_addr = new_work ? (data_valid ? data_addr : inst1_valid ? inst1_addr : inst2_addr) 
            : (state == DATA ? data_addr : state == INST1 ? inst1_addr : inst2_addr);
    // INST query only 4 Byte
    assign mu_len = new_work ? (data_valid ? data_len : 3'b010) : (state == DATA ? data_len : 3'b010);
    assign mu_value = data_value;

    assign data_result = state == DATA ? mu_result : 0;
    assign data_ready = mu_ready && state == DATA;

    assign inst1_result = state == INST1 ? mu_result : 0;
    assign inst1_ready = mu_ready && state == INST1;

    assign inst2_result = state == INST2 ? mu_result : 0;
    assign inst2_ready = mu_ready && state == INST2;

    wire [1:0] next_state = data_valid ? DATA : inst1_valid ? INST1 : inst2_valid ? INST2 : IDLE;

    always @(posedge clk_in) begin
        if (rst_in) begin
            state <= IDLE;
        end
        else if (rob_clear) begin
            // state <= next_state;
            state <= IDLE;
        end
        else if (rdy_in) begin
            case(state)
                IDLE: begin
                    if (data_valid) begin
                        state <= DATA;
                    end
                    else if (inst1_valid) begin
                        state <= INST1;
                    end
                    else if (inst2_valid) begin
                        state <= INST2;
                    end
                end
                INST1: begin
                    if (mu_ready) begin
                        state <= next_state;
                    end
                end
                INST2: begin
                    if (mu_ready) begin
                        state <= next_state;
                    end
                end
                DATA: begin
                    if (mu_ready) begin
                        state <= next_state;
                    end
                end
            endcase
        end
    end

endmodule