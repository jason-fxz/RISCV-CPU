`define ROB_SIZE_BIT 5
`define ROB_SIZE (1 << `ROB_SIZE_BIT)


`define RS_TYPE_BIT 6
// 543210
// 01yxxx  Arith R/I-type;  xxx for funct3, y for funct7[5] (Add/Sub, SRL/SRA)
// 110xxx  Branch B-type;   xxx for funct3
// 10yxxx  Load/Store;      xxx for funct3, y for load(0)/store(1)
`define RS_SIZE_BIT 3
`define (1 << `RS_SIZE_BIT)