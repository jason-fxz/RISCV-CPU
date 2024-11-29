`define ROB_SIZE_BIT 3
`define ROB_SIZE (1 << `ROB_SIZE_BIT)


`define RS_TYPE_BIT 5
// 43210
// 0yxxx  Arith R/I-type;  xxx for funct3, y for funct7[5] (Add/Sub, SRL/SRA)
// 10xxx  Branch B-type;   xxx for funct3
`define RS_SIZE_BIT 3
`define RS_SIZE (1 << `RS_SIZE_BIT)

`define LSB_TYPE_BIT 4
// 3210
// 0xxx  Load I-type;  xxx for funct3
// 1xxx  Store S-type; xxx for funct3
`define LSB_SIZE_BIT 3
`define LSB_SIZE (1 << `LSB_SIZE_BIT)

`define ROB_TYPE_BIT 2
`define ROB_RG 2'b00 // save to register
`define ROB_ST 2'b01 // store to mem
`define ROB_BR 2'b10 // branch (predict 0)
`define ROB_BR1 2'b11 // branch (predict 1) 

`define ICACHE_SIZE_BIT 5