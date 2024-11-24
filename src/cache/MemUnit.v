// a simple unit to handle memory access
// read/write Byte/Halfword/Word

/// Behavior:
//  ready unset:
//    set valid to work. wr, addr, len, data_in should not be changed
//  ready set:
//    


module MemUnit(
    input wire clk_in,        // system clock signal
    input wire rst_in,        // reset signal
    input wire rdy_in,        // ready signal, pause cpu when low

    // to ram
    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)

    input  wire                 io_buffer_full, // 1 if uart buffer is full (TODO: ignore this first)

    input  wire                 valid,   // valid signal
    input  wire                 wr,      // 1 write/ 0 read 
    input  wire [31:0]          addr,    // memory address
    // len[2]: 0 for signed / 1 for unsigned
    // len[1:0]: 2'b00 Byte / 2'b01 Halfword / 2'b10 Word
    input  wire [ 2:0]          len,
    input  wire [31:0]          data_in, // data to write
    output wire [31:0]          data_out, // data read
    output wire                 ready,

    input  wire                 rob_clear
);
    reg           cur_wr;
    reg    [31:0] cur_addr;
    reg    [2:0]  cur_len;
    reg    [31:0] cur_data_in; // data to write

    reg    [7:0]  cur_data_to_write; // data to write (cur) 

    reg    [31:0] tmp_data; // data have read


    // State: have read x Byte
    reg    [1:0]  state;

    wire   need_work = valid;
    wire   totalbyte = len[1] ? 4 : len[0] ? 2 : 1;
    assign ready = valid && (totalbyte - 1 == state);

    wire   direct = (state == 2'b00) && need_work;
    assign mem_a = direct ? addr : cur_addr;
    assign mem_wr = direct ? wr : cur_wr;
    assign mem_dout = direct ? data_in[7:0] : cur_data_to_write;


    always @(posedge clk_in) begin
        if (rst_in || rob_clear) begin
            state <= 0;
            cur_addr <= 0;
            cur_len <= 0;
            cur_wr <= 0;
            cur_data_in <= 0;
            cur_data_to_write <= 0;
            tmp_data <= 0;
            // ready <= 0;
        end
        else if (rdy_in) begin
            // ready <= 0;
            case (state)
                2'b00: begin
                    if (need_work) begin
                        cur_data_in <= data_in;
                        cur_len <= len;
                        if (len[1:0]) begin // Halfword or Word
                            state <= 2'b01;
                            cur_wr <= wr;
                            cur_addr <= addr + 1; // next addr
                            cur_data_to_write <= data_in[15:8]; // next write
                        end
                        else begin // Byte: END
                            state <= 2'b00;
                            cur_data_to_write <= 0;
                            cur_wr <= 0;
                            cur_addr <= 0;
                            // ready <= 1;
                        end
                    end
                end
                2'b01: begin
                    tmp_data[7:0] <= mem_din; // read data
                    if (cur_len[1:0] == 2'b01) begin// Halfword: END
                        state <= 2'b00;
                        cur_data_to_write <= 0;
                        cur_wr <= 0;
                        cur_addr <= 0;
                        // ready <= 1;
                    end
                    else begin // Word
                        state <= 2'b10;
                        cur_addr <= cur_addr + 1; // next addr
                        cur_data_to_write <= data_in[23:16]; // next write
                    end
                end
                2'b10: begin
                    state <= 2'b11;
                    tmp_data[15:8] <= mem_din; // read data
                    cur_addr <= cur_addr + 1;
                    cur_data_to_write <= data_in[31:24];
                end
                2'b11: begin
                    state <= 2'b00;
                    tmp_data[23:16] <= mem_din; // read data
                    cur_data_to_write <= 0;
                    cur_wr <= 0;
                    cur_addr <= 0;
                    // ready <= 1;
                end
            endcase
        end
    end


    // read is by wire 
    function [31:0] gen_read_data;
        input [2:0] len;
        input [31:0] tmp_data;
        input [7:0] mem_din;
        case (len)
            3'b000: gen_read_data = {{24{mem_din[7]}}, mem_din}; // lb
            3'b100: gen_read_data = {24'b0, mem_din}; // lbu
            3'b001: gen_read_data = {{16{mem_din[7]}}, mem_din, tmp_data[7:0]}; // lh
            3'b101: gen_read_data = {16'b0, mem_din, tmp_data[7:0]}; // lhu
            3'b010: gen_read_data = {mem_din, tmp_data[23:0]}; // lw
            default: gen_read_data = 0;
        endcase 
    endfunction

    assign data_out = gen_read_data(cur_len, tmp_data, mem_din);
    
endmodule //MemUnit

