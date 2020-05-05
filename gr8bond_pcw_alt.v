/*
Notes:
	VMEM0: Instruction Memory
	VMEM1: Data Memory
	VMEM2: 16-bit lookup table
	VMEM3: 8-bit lookup table
	VMEM4: Inverse float lookup table

*/

//Change these to switch between CGI and iVerilog
//Uncomment for CGI, comment for Icarus
/*
`define LOADTEXT	$readmemh0(text)
`define LOADDATA	$readmemh1(data)
`define LOAD16		$readmemh2(table16)
`define LOAD8		$readmemh3(table8)
`define LOADINVF	$readmemh4(look)
`define DUMP		$dumpfile
*/

//Uncomment for Icarus, comment for CGI
`define LOADTEXT	$readmemh("gr8bond.text", text)
`define LOADDATA	$readmemh("gr8bond.data", data)
`define LOAD16		$readmemh("posit1624.vmem", table16)
`define LOAD8		$readmemh("posit840.vmem", table8)
`define LOADINVF	$readmemh("invF.vmem", look)
`define DUMP		$dumpfile("gr8bond.vcd")

//sizes
`define OPSIZE		[3:0]
`define WORD        [15:0]
`define NUMREGS     [15:0]
`define MEMSIZE 	[0:65535]
`define STATE       [3:0]
`define FCNSTATE	[3:0]

//data parts of the instruction
`define OPCODELOC	[15:12]
`define FCNCODELOC  [11:8]
`define RDLOC 		[3:0]
`define RSLOC 		[7:4]	
`define IMMEDIATELOC[11:4]

//WHAT REGISTERS ARE WHAT
`define AT          [11]
`define RV          [12]
`define RA          [13]
`define FP          [14]
`define SP          [15]

//OP CODES
`define OPbz		4'he
`define OPbnz		4'hf
`define OPci8		4'hb  //use rd
`define OPcii		4'hc  //use rd
`define OPcup		4'hd  //use rd
`define OPINTS		4'h7  //use rd
`define OPPOSITS	4'h6  //use rd
`define OPBITWISE	4'h5  //use rd
`define OPMEM		4'h4  
`define OPANYNEG    4'h3  //use rd
`define OPCONVERT	4'h2  //use rd
`define OPOTHER		4'h1
`define OPtrap		4'h0

//FCN CODES
//OPINTS
`define FCNaddi		4'h0
`define FCNaddii	4'h1
`define FCNmuli		4'h2
`define FCNmulii	4'h3
`define FCNshi		4'h4
`define FCNshii 	4'h5
`define FCNslti		4'h6
`define FCNsltii	4'h7
`define FCNdup		4'h8
//OPPOSITS
`define FCNaddf		4'h0
`define FCNaddpp	4'h1
`define FCNmulf		4'h2
`define FCNmulpp	4'h3
`define FCNnegf		4'h4
//OPBITWISE
`define FCNand		4'h0
`define FCNor 		4'h1
`define FCNxor		4'h2
//OPMEM
`define FCNld		4'h0  
`define FCNst		4'h1 //use rd
//OPANYNEG
`define FCNanyi     4'h0
`define FCNanyii	4'h1
`define FCNnegi		4'h2
`define FCNnegii	4'h3
//OPCONVERT
`define FCNi2f		4'h0
`define FCNii2pp	4'h1
`define FCNf2i		4'h2
`define FCNpp2ii	4'h3
`define FCNinvf		4'h4
`define FCNinvpp	4'h5
`define FCNf2pp		4'h6
`define FCNpp2f		4'h7
//OPOTHER
`define FCNnot		4'h0  //use rd
`define FCNjr		4'h1

//STATES
`define NOP  		4'ha

//Floating Point Stuff
//Field Definitions
`define	INT			signed [15:0]	// integer size
`define FLOAT		[15:0]
`define FEXP		[14:7]	// exponent
`define FFRAC		[6:0]	// fractional part (leading 1 implied)
`define FSIGN		[15]	// sign bit

// Constants
`define	FZERO	16'b0	  // float 0
`define F32767  16'h46ff  // closest approx to 32767, actually 32640
`define F32768  16'hc700  // -32768

`define HighBits	[15:8]
`define LowBits		[7:0]


// Count leading zeros, 16-bit (5-bit result) d=lead0s(s)
module lead0s(d, s);
	output wire [4:0] d;
	input wire `WORD s;
	wire [4:0] t;
	wire [7:0] s8;
	wire [3:0] s4;
	wire [1:0] s2;
	assign t[4] = 0;
	assign {t[3],s8} = ((|s[15:8]) ? {1'b0,s[15:8]} : {1'b1,s[7:0]});
	assign {t[2],s4} = ((|s8[7:4]) ? {1'b0,s8[7:4]} : {1'b1,s8[3:0]});
	assign {t[1],s2} = ((|s4[3:2]) ? {1'b0,s4[3:2]} : {1'b1,s4[1:0]});
	assign t[0] = !s2[1];
	assign d = (s ? t : 16);
endmodule

// Float set-less-than, 16-bit (1-bit result) torf=a<b
module fslt(torf, a, b);
output wire torf;
input wire `FLOAT a, b;
assign torf = (a `FSIGN && !(b `FSIGN)) ||
	      (a `FSIGN && b `FSIGN && (a[14:0] > b[14:0])) ||
	      (!(a `FSIGN) && !(b `FSIGN) && (a[14:0] < b[14:0]));
endmodule

// Floating-point addition, 16-bit r=a+b
module fadd(r, a, b);
	output wire `FLOAT r;
	input wire `FLOAT a, b;
	wire `FLOAT s;
	wire [8:0] sexp, sman, sfrac;
	wire [7:0] texp, taman, tbman;
	wire [4:0] slead;
	wire ssign, aegt, amgt, eqsgn;
	assign r = ((a == 0) ? b : ((b == 0) ? a : s));
	assign aegt = (a `FEXP > b `FEXP);
	assign texp = (aegt ? (a `FEXP) : (b `FEXP));
	assign taman = (aegt ? {1'b1, (a `FFRAC)} : ({1'b1, (a `FFRAC)} >> (texp - a `FEXP)));
	assign tbman = (aegt ? ({1'b1, (b `FFRAC)} >> (texp - b `FEXP)) : {1'b1, (b `FFRAC)});
	assign eqsgn = (a `FSIGN == b `FSIGN);
	assign amgt = (taman > tbman);
	assign sman = (eqsgn ? (taman + tbman) : (amgt ? (taman - tbman) : (tbman - taman)));
	lead0s m0(slead, {sman, 7'b0});
	assign ssign = (amgt ? (a `FSIGN) : (b `FSIGN));
	assign sfrac = sman << slead;
	assign sexp = (texp + 1) - slead;
	assign s = (sman ? (sexp ? {ssign, sexp[7:0], sfrac[7:1]} : 0) : 0);
endmodule


// Floating-point multiply, 16-bit r=a*b
module fmul(r, a, b);
	output wire `FLOAT r;
	input wire `FLOAT a, b;
	wire [15:0] m; // double the bits in a fraction, we need high bits
	wire [7:0] e;
	wire s;
	assign s = (a `FSIGN ^ b `FSIGN);
	assign m = ({1'b1, (a `FFRAC)} * {1'b1, (b `FFRAC)});
	assign e = (((a `FEXP) + (b `FEXP)) -127 + m[15]);
	assign r = (((a == 0) || (b == 0)) ? 0 : (m[15] ? {s, e, m[14:8]} : {s, e, m[13:7]}));
endmodule

// Floating-point reciprocal, 16-bit r=1.0/a
// Note: requires initialized inverse fraction lookup table
module frecip(r, a);
	output wire `FLOAT r;
	input wire `FLOAT a;
	reg [6:0] look[127:0];
	initial `LOADINVF;
	assign r `FSIGN = a `FSIGN;
	assign r `FEXP = 253 + (!(a `FFRAC)) - a `FEXP;
	assign r `FFRAC = look[a `FFRAC];
endmodule

// Float to integer conversion, 16 bit
// Note: out-of-range values go to -32768 or 32767
module f2i(i, f);
	output wire `INT i;
	input wire `FLOAT f;
	wire `FLOAT ui;
	wire tiny, big;
	fslt m0(tiny, f, `F32768);
	fslt m1(big, `F32767, f);
	assign ui = {1'b1, f `FFRAC, 16'b0} >> ((128+22) - f `FEXP);
	assign i = (tiny ? 0 : (big ? 32767 : (f `FSIGN ? (-ui) : ui)));
endmodule

// Integer to float conversion, 16 bit
module i2f(f, i);
output wire `FLOAT f;
input wire `INT i;
wire [4:0] lead;
wire `WORD pos;
assign pos = (i[15] ? (-i) : i);
lead0s m0(lead, pos);
assign f `FFRAC = (i ? ({pos, 8'b0} >> (16 - lead)) : 0);
assign f `FSIGN = i[15];
assign f `FEXP = (i ? (128 + (14 - lead)) : 0);
endmodule

module fpu(rd,rs,op,fpuOut);
	input `WORD rd;
	input wire `WORD rs;
	input wire `OPSIZE op;
	output wire `WORD fpuOut;
	wire `WORD addfOut, invfOut, f2iOut, i2fOut, mulfOut;
	
	reg [23:0] table16[65535:0];
	reg [39:0] table8[255:0];
	initial begin
		`LOAD16;
		`LOAD8;
	end
	
	
	reg `WORD out;
	assign fpuOut = out;
	
	fmul mulf(mulfOut, rd, rs);
	fadd addf(addfOut, rd, rs);
	frecip invf(invfOut, rd);
	f2i fl2int(f2iOut, rd);
	i2f int2fl(i2fOut, rd);
	
	
/*	
`define FCNi2f		4'h0
`define FCNii2pp	4'h1
`define FCNf2i		4'h2
`define FCNpp2ii	4'h3
`define FCNinvf		4'h4
`define FCNinvpp	4'h5
`define FCNf2pp		4'h6
`define FCNpp2f		4'h7

//OPPOSITS
`define FCNaddf		4'h0
`define FCNaddpp	4'h1
`define FCNmulf		4'h2
`define FCNmulpp	4'h3
*/
	always @* begin
		case (op)
			//Math
			// commented out 16-bit table usage, as it causes INSANE compile times. Approx. 2 minutes with 1 item enabled, 6 minutes when 2 of the 3 items are enabled, and about 9 when all three are enabled.
			/*
			`FCNaddpp: 
				begin 
					out`HighBits = table16[{rd`HighBits,rs`HighBits}][23:16];
					out`LowBits = table16[{rd`LowBits,rs`LowBits}] [23:16];
					#1$display("addpp %h, %h = %h",rd,rs,out);
				end
			`FCNf2pp: 
				begin
					out`HighBits = table16[rd][7:0];
					out`LowBits = table16[rd][7:0];
					#1$display("f2pp %h, %h = %h",rd,rs,out);
				end
			`FCNmulpp: 
				begin
					out`HighBits = table16[{rd`HighBits,rs`HighBits}][15:8];
					out`LowBits = table16[{rd`LowBits,rs`LowBits}] [15:8];
					#1$display("mulpp %h, %h = %h",rd,rs,out);
				end
			*/	
			`FCNaddf:
				begin
					out = addfOut;
					#1$display("mulf %h, %h = %h",rd,rs,out);
				end
			`FCNmulf:
				begin
					out = mulfOut;
					#1$display("mulf %h, %h = %h",rd,rs,out);
				end
			`FCNnegf: 
				begin
					// negate MSB of rd and concatenate with rest of rd
					out = {~rd[15], rd[14:0]};
					#1$display("negf %h = %h",rd,out);
				end
			`FCNinvf: 
				begin
					out = invfOut;
					#1$display("invf %h = %h",rd,out);
				end
			`FCNinvpp: 
				begin
					out = {table8[rd `HighBits][39:32], table8[rd `LowBits][39:32]};
					#1$display("invpp %h, %h = %h",rd,rs,out);
				end
			
			//Conversion
			`FCNf2i: 
				begin 
					out = f2iOut;
					#1$display("f2i %h = %h",rd,out);
				end
			`FCNi2f: 
				begin
					out = i2fOut;
					#1$display("i2f %h = %h",rd,out);
				end
			`FCNii2pp: 
				begin
					out = {table8[rd `HighBits][7:0], table8[rd `LowBits][7:0]};
					#1$display("ii2pp %h = %h",rd,out);
				end
			`FCNpp2f: 
				begin
					out = table8[rd `LowBits][31:16];
					#1$display("pp2f %h = %h",rd,out);
				end
			`FCNpp2ii: 
				begin
					out = {table8[rd `HighBits][15:8], table8[rd `LowBits][15:8]};
					#1$display("pp2ii %h = %h",rd,out);
				end
			default: begin end
		endcase
	end
	
endmodule


module processor(output reg halted, input reset, input clk);

reg `WORD text `MEMSIZE; // instruction memory
reg `WORD data `MEMSIZE; // data memory
reg `WORD registers `NUMREGS;
reg `WORD address; // address to jump or branch to
reg jump; //are we jumping or branchigng?
reg `WORD instructionReg0, instructionReg1, instructionReg2, instructionRegTemp;
reg `WORD pc0, pc1;
reg `WORD target, result;
reg `WORD rd, rs;
wire pendPC;
wire stall;
reg goingToHalt;
wire `WORD fpuOut;

fpu myfpu(rd, rs, instructionReg1`FCNCODELOC, fpuOut);

function setsPC;
input `WORD inst;
setsPC = ((inst `OPCODELOC == `OPbz) ||
		  (inst `OPCODELOC == `OPbnz) ||
		  (instructionReg2 `OPCODELOC == `OPOTHER &&
	       instructionReg2 `FCNCODELOC == `FCNjr));		  
endfunction

//needs to check if we need to stall
function usesSameRD;
input `WORD inst1, inst2;
usesSameRD = (((inst1 `RDLOC == inst2 `RDLOC) || (inst1 `RDLOC == inst2 `RSLOC) || (inst1 `RSLOC == inst2 `RDLOC)) &&
              ((inst1 `OPCODELOC != `NOP) && (inst2 `OPCODELOC != `NOP)));
endfunction

// pending PC update?
assign pendPC = (setsPC(instructionReg0) || setsPC(instructionReg1) || setsPC(instructionReg2));

assign stall = (usesSameRD(instructionReg0, instructionReg1) || usesSameRD(instructionReg0, instructionReg2));

always @ (reset) begin
  pc0 = 0;
  pc1 = 0;
  halted = 0;
  jump = 0;
  address = 0;
  goingToHalt = 0;
  instructionReg0 = 16'ha000;
  instructionReg1 = 16'ha000;
  instructionReg2 = 16'ha000;
  `LOADTEXT; 
  `LOADDATA;
end

//Stage 0: Inst. Fetch
//owns pc, instructionReg0
//needs to get the instruction and increment/pick the PC
//also needs to send nothing down the line
//if there is not a pendingPC update, pc <= pc + 1, if there is wait until 
//if we are waiting make ir == nop
//if we are halted do nothing
always @ (posedge clk) begin
	//$display("0 %b",registers[0]);
	//$display("1 %b",registers[1]);
	//$display("2 %b",registers[2]);
	//$display("3 %b",registers[3]);
	//$display("4 %b",registers[4]);
	//$display();
	if(stall == 1) begin
		instructionReg0 <= instructionReg0;
		pc0 <= pc0;
	end else begin
		if(pendPC == 1) begin
			instructionReg0 <= 16'ha000;
			pc0 <= pc0;
		end else begin
			if(jump == 1) begin
				pc0 <= address + 1;
				instructionReg0 <= text[address];
				jump <= 0;
			end else begin
				pc0 <= pc0 + 1;
				instructionReg0 <= text[pc0];
			end
		end
	end
	//$display("Stage 0: %h, %d",instructionReg0, pc0);
end

//Stage 1: Reg. Read
//owns pc1, instructionReg1, rd, rs, immediate
//needs to get the values from the regs and pull out the imm value
always @ (posedge clk) begin
	if(stall == 1) begin
		instructionReg1 <= 16'ha000;
		pc1 <= pc1;
	end else begin
		rd <= registers[instructionReg0 `RDLOC];
		rs <= registers[instructionReg0 `RSLOC];
		instructionReg1 <= instructionReg0;
		pc1 <= pc0;
	end
	//$display("Stage 1: %h, %d",instructionReg0, pc1);
end

//Stage 2: ALU/Mem
//owns result, instructionReg2, and mem block
//does math and writes to mem
always @ (posedge clk) begin
	instructionReg2 <= instructionReg1;
	case(instructionReg1 `OPCODELOC)
    // Dummy codes
    `NOP : begin end 

    // 	Codes without functions
    `OPtrap : begin goingToHalt <= 1; end
    `OPbz : begin 
				if(rd == 0) begin
					result <= pc1 + instructionReg1 `IMMEDIATELOC - 1;
				end else begin
					result <= pc1;
				end
			end
    `OPbnz : begin 
				if(rd != 0) begin 
					result <= pc1 + instructionReg1 `IMMEDIATELOC - 1;
				end	else begin
					result <= pc1;
				end
			end
/*    `OPci8 : begin if(instructionReg1 `IMMEDIATELOC[7] == 0) result[15:8] <= 8'h00;
	               else result[15:8] <= 8'hff;
				   result[7:0] <= instructionReg1 `IMMEDIATELOC; 
				    end 
*/    `OPcii : begin result[7:0] <= instructionReg1 `IMMEDIATELOC;
                   result[15:8] <= instructionReg1 `IMMEDIATELOC;
                    end
    `OPcup : begin result[15:8] <= instructionReg1 `IMMEDIATELOC;  end
	
	
    // Codes with Functions
    `OPINTS : begin 
                case(instructionReg1 `FCNCODELOC)
					`FCNaddi : begin
						result <= rd + rs; 
						 end
					`FCNaddii : begin
						result[15:8] <= rd[15:8] + rs[15:8];
						result[7:0] <= rd[7:0] + rs[7:0]; 
						 end
					`FCNmuli : begin 
						result <= rd * rs; 
						 end
					`FCNmulii : begin 
						result[15:8] <= rd[15:8] * rs[15:8];
						result[7:0] <= rd[7:0] * rs[7:0]; 
						 end
					`FCNshi : begin 
						if(rs > 0)
							result <=  rd << rs;
						else
							result <= rd >> -rs;
						 end
					`FCNshii : begin 
						if(rs[15:8] > 0)
							result[15:8] <=  rd[15:8] << rs[15:8];
						else
							result[15:8] <= rd[15:8] >> -rs[15:8];
						if(rs[7:0] > 0)
							result[7:0] <=  rd[7:0] << rs[7:0];
						else
							result[7:0] <= rd[7:0] >> -rs[7:0];	
							end
					`FCNslti : begin result <= rd < rs;
						 end
					`FCNsltii : begin 
						result[15:8] <= rd[15:8] < rs[15:8];
						result[7:0] <= rd[7:0] < rs[7:0];
						 end
					`FCNdup : begin
						result <= rs;
						end
					
					default : begin goingToHalt <= 1; end
				endcase
			  end
	
    `OPMEM : begin 
                case(instructionReg1 `FCNCODELOC)
					`FCNld : begin 
						result <= data[rs];
						 end
					`FCNst : begin 
						data[rs] <= rd;
						 end
						
					default : begin goingToHalt <= 1; end
				endcase
			 end
	
	`OPANYNEG : begin
					case(instructionReg1 `FCNCODELOC)
						`FCNanyi : begin 
							if(rd == 0)
								result <= 0;
							else result <= -1;
							 end
						`FCNanyii : begin 
							if(rd[15:8] == 0)
								result[15:8] <= 0;
							else rd[15:8] <= -1;
							if(rd[7:0] == 0)
								result[7:0] <= 0;
							else rd[7:0] <= -1;
							 end
						`FCNnegi : begin 
							result <= -rd;
							 end
						`FCNnegii : begin 
							result[15:8] <= -rd[15:8];
							result[7:0] <= -rd[7:0];
							 end
						
						default : begin goingToHalt <= 1; end
					endcase
				end
	
    `OPBITWISE : begin
					case(instructionReg1 `FCNCODELOC)
						`FCNand : begin
							result <= rd & rs; 
							 end
						`FCNor : begin 
							result <= rd | rs; 
							 end
						`FCNxor : begin
							result <= rd ^ rs; 
							 end
						
						default : begin goingToHalt <= 1; end
					endcase
				  end
	
    `OPOTHER : begin 
                    case(instructionReg1 `FCNCODELOC)
						`FCNnot : begin 
							result <= ~rd; 
							 end
						`FCNjr : begin result <= rd;  end
						 
						default : begin goingToHalt <= 1; end
					endcase

			   end

	//dont need to implement
    `OPCONVERT : begin goingToHalt <= 1; end
	`OPPOSITS : begin goingToHalt <= 1; end
	//dont need to implement
	
    default : begin goingToHalt <= 1; end
    endcase
	
end
  
//Stage 3: Reg. Write
//owns address, and reg block
//writes results to registers
always @ (posedge clk) begin
	if(goingToHalt == 1) begin
		halted <= 1; end
    if(instructionReg2 `OPCODELOC == `OPbz ||
	   instructionReg2 `OPCODELOC == `OPbnz ||
	   (instructionReg2 `OPCODELOC == `OPOTHER &&
	    instructionReg2 `FCNCODELOC == `FCNjr))begin
		jump <= 1;
		address <= result;
	end else begin
		if((instructionReg2 `OPCODELOC == `OPMEM) &&
		   (instructionReg2 `FCNCODELOC == `FCNst)) begin
			
			end else begin
				registers[instructionReg2 `RDLOC] <= result;
			end
	end
end
endmodule
 
 
 
module testbench;
reg reset = 0;
reg clk = 0;
wire halt;
processor PE(halt, reset, clk);
initial begin
  `DUMP;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halt) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
