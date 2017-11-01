module opc7cpu(input[31:0] din,input clk,input reset_b,input[1:0] int_b,input clken,output vpa,output vda,output vio,output[31:0] dout,output[19:0] address,output rnw);    
  parameter MOV=5'h0,MOVT=5'h1,XOR=5'h2,AND=5'h3,OR=5'h4,NOT=5'h5,CMP=5'h6,SUB=5'h7,ADD=5'h8,BROT=5'h9,ROR=5'hA,LSR=5'hB,JSR=5'hC,ASR=5'hD,ROL=5'hE;
  parameter HLT=5'h10,RTI=5'h11,PPSR=5'h12,GPSR=5'h13,DIVS=5'h16,MULS=5'h17,OUT=5'h18,IN=5'h19,STO=5'h1A,LD=5'h1B,LJSR=5'h1C,LMOV=5'h1D,LSTO=5'h1E,LLD=5'h1F;
  parameter FET=3'h0,EAD=3'h1,RDM=3'h2,EXEC=3'h3,WRM=3'h4,INT=3'h5, P0=31,P1=30,P2=29,EI=3,S=2,C=1,Z=0,INT_VECTOR0=20'h2,INT_VECTOR1=20'h4;
  reg [19:0]  PC_q,PCI_q;(* RAM_STYLE="DISTRIBUTED" *)
  reg [31:0]  RF_q[14:0], RF_pipe_q, OR_q,result;
  reg [7:0]   PSR_q;
  reg [4:0]   IR_q;
  reg [3:0]   swiid,PSRI_q,dst_q,src_q;  
  reg [2:0]   FSM_q;  
  reg         zero,carry,sign,enable_int,reset_s0_b,reset_s1_b,subnotadd_q, ms_q;
  wire        pred_din      = (din[P2] ^ (din[P1]?(din[P0]?PSR_q[S]:PSR_q[Z]):(din[P0]?PSR_q[C]:1))); // New data,old flags (in fetch0)
  wire        pred_d        = (din[P2] ^ (din[P1] ? (din[P0] ? sign : zero): (din[P0] ? carry : 1))); // New data,new flags (in exec/fetch)
  wire [31:0] RF_dout       = (dst_q==4'hF)? {12'b0,PC_q} : RF_q[dst_q] & {32{(|dst_q)}}; 
  wire [31:0] RF_sout       =  {32{(|src_q)&&IR_q[4:2]!=3'b111}} & ((src_q==4'hF)? {12'b0,PC_q} : RF_q[src_q]);
  wire [32:0] ms_d          = RF_dout - RF_sout ; // only interested in b32 (carry out) in DIVS    
  assign {rnw,dout,address} = {!(FSM_q==WRM), RF_pipe_q,(FSM_q==WRM||FSM_q==RDM)? OR_q[19:0] : PC_q};  
  assign {vpa,vda,vio}      = {(FSM_q==FET||FSM_q==EXEC),({2{FSM_q==RDM||FSM_q==WRM}}&{!(IR_q==IN||IR_q==OUT),IR_q==IN||IR_q==OUT})};    
  always @( * ) begin
    case (IR_q)
      AND,OR       :{carry,result} = {PSR_q[C],(IR_q==AND)?(RF_pipe_q & OR_q):(RF_pipe_q | OR_q)};
      MOVT,ROL     :{carry,result} = (IR_q==ROL)? {OR_q, PSR_q[C]} :{PSR_q[C], OR_q[15:0], RF_pipe_q[15:0]} ;
      ADD,SUB,CMP,MULS,DIVS :{carry,result} = (ms_q)? RF_pipe_q + OR_q + subnotadd_q: {1'b0,RF_pipe_q}; // OR_q pre-negated in EAD for sub/cmp/divs      
      XOR,GPSR     :{carry,result} = (IR_q==GPSR)?{PSR_q[C],8'b0,PSR_q}:{PSR_q[C],RF_pipe_q ^ OR_q};
      NOT,BROT     :{result,carry} = (IR_q==NOT)? {~OR_q,PSR_q[C]} : {OR_q[7:0],OR_q[31:8],PSR_q[C]};
      ROR,ASR,LSR  :{result,carry} = {(IR_q==ROR)?PSR_q[C]:(IR_q==ASR)?OR_q[31]:1'b0,OR_q};
      JSR,LJSR     :{result,carry} = { 12'b0, PC_q, PSR_q[C]};      
      default      :{carry,result} = {PSR_q[C],OR_q} ; //LD,MOV,STO,IN,OUT and everything else
    endcase // case ( IR_q )
    {swiid,enable_int,sign,carry,zero} = (IR_q==PPSR)?OR_q[7:0]:(dst_q!=4'hF)?{PSR_q[7:3],result[31],carry,!(|result)}:PSR_q;
  end // always @ ( * )    
  always @(posedge clk)
    if (clken) begin        
      {reset_s0_b,reset_s1_b} <= {reset_b,reset_s0_b};
      if (!reset_s1_b)
        {PC_q,PCI_q,PSRI_q,PSR_q,FSM_q} <= 0;
      else begin
        {RF_pipe_q, ms_q} <= (IR_q==MULS)? ({1'b0,RF_dout}): (IR_q==DIVS) ?{RF_dout[30:0],1'b0, ms_d[32]} : {RF_dout, 1'b1};          
        OR_q  <= (FSM_q==RDM)?din: (FSM_q==EAD) ? (RF_sout+OR_q) ^ {32{IR_q==SUB||IR_q==CMP}}:{(din[28:26]==3'h7)?{12'b0,din[19:16]}:{16{din[15]}}, din[15:0]};
        subnotadd_q  <= (IR_q!=ADD&&IR_q!=MULS) ;
        case (FSM_q)
          FET    : FSM_q <= (!pred_din) ? FET : EAD ; 
          EAD    : FSM_q <= (IR_q==LD||IR_q==LLD||IR_q==IN) ? RDM : (IR_q==STO||IR_q==LSTO||IR_q==OUT) ? WRM : EXEC;     
          EXEC   : FSM_q <= ((!(&int_b) & PSR_q[EI])||(IR_q==PPSR&&(|swiid)))?INT:(dst_q==4'hF||(!pred_d)||IR_q==JSR||IR_q==LJSR)?FET:EAD;                              
          WRM    : FSM_q <= (!(&int_b) & PSR_q[EI])?INT:FET;                  
          default: FSM_q <= (FSM_q==RDM)? EXEC : FET;  
        endcase            
        if ((FSM_q==FET)||(FSM_q==EXEC))
          {IR_q, dst_q, src_q} <= din[28:16] ;
        else if (FSM_q==EAD & IR_q==CMP )
          dst_q <= 4'b0; // Zero dest address after reading it in EAD for CMP operations                 
        if ( FSM_q == INT )
          {PC_q,PCI_q,PSRI_q,PSR_q[EI]} <= {(!int_b[1])?INT_VECTOR1:INT_VECTOR0,PC_q,PSR_q[3:0],1'b0}; 
        else if (FSM_q==FET) 
          PC_q  <= PC_q + 1;
        else if ( FSM_q == EXEC) begin
          PC_q <= (IR_q==RTI)?PCI_q: (dst_q==4'hF) ? result[19:0] : (IR_q==JSR||IR_q==LJSR)? OR_q[19:0]:((!(&int_b)&&PSR_q[EI])||(IR_q==PPSR&&(|swiid)))?PC_q:PC_q + 1;
          PSR_q <= (IR_q==RTI)?{4'b0,PSRI_q}:{swiid,enable_int,sign,carry,zero}; 
          RF_q[dst_q] <= result;
        end
      end 
    end
endmodule
