`define FETCH0 2'b00
`define FETCH1 2'b01
`define RDMEM  2'b10
`define EXEC   2'b11
`define ANDI 5'h10
`define AND  5'h00
`define LDAI 5'h12
`define LDA  5'h02
`define STA  5'h04
`define NOT  5'h14
`define ADDI 5'h16
`define ADD  5'h06
`define JPC  5'h0A
`define JPZ  5'h0C
`define JP   5'h0E

module opccpu( data, address, rnw, clk, reset_b );
  inout[7:0] data;
  output[11:0] address;
  output rnw;
  input clk, reset_b;

  reg [11:0] OR_q, PC_q;
  reg [8:0]  ACC_q;
  reg [1:0]  FSM_q;
  reg [4:0]  IR_q;
  reg        C_q;
  wire writeback_w = (FSM_q == `EXEC) && (IR_q == `STA);
  assign data = (writeback_w)?ACC_q:8'bz ;
  assign address = (writeback_w || FSM_q == `RDMEM )? OR_q:PC_q;
  assign rnw = ~writeback_w;

  always @ (posedge clk or negedge reset_b )
    if (!reset_b)
      FSM_q <= `FETCH0;
    else
      case(FSM_q)
        `FETCH0 : FSM_q <= `FETCH1;
        `FETCH1 : FSM_q <= (IR_q[4]==0)?`EXEC:`RDMEM ;
        `RDMEM  : FSM_q <= `EXEC;
        `EXEC   : FSM_q <= `FETCH0;
      endcase

  always @ (posedge clk)
    begin
      IR_q <= (FSM_q == `FETCH0)? { data[7:4], data[7] & data[3]} : IR_q; // IR bit 0 always reset for DIRECT mode instr
      OR_q[11:8] <= (FSM_q == `FETCH0)? data[3:0]: OR_q[11:8];
      OR_q[7:0] <= (FSM_q == `FETCH1 || FSM_q==`RDMEM)? data: OR_q[7:0];
      if ( FSM_q == `EXEC )
        case(IR_q)
          `ANDI, `AND : {C_q, ACC_q}  <= {1'b0, ACC_q & OR_q[7:0]};
          `NOT	      : ACC_q <= ~ACC_q;
          `LDAI,`LDA  : ACC_q <= OR_q[7:0];
          `ADDI,`ADD  : {C_q,ACC_q} <= ACC_q + C_q + OR_q[7:0];
        endcase
    end

  always @ (posedge clk or negedge reset_b )
    if (!reset_b)
      PC_q <= 12'b0;
    else
      begin
        if ( FSM_q == `FETCH0 || FSM_q == `FETCH1 )
          PC_q <= PC_q + 1;
        else if ( FSM_q == `EXEC )
          case (IR_q)
            `JP    : PC_q <= OR_q;
            `JPC   : PC_q <= (C_q)?OR_q:PC_q;
            `JPZ   : PC_q <= (|ACC_q)?OR_q:PC_q;
            default: PC_q <= PC_q;
          endcase
      end
endmodule
