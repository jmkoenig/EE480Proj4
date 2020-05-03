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


// Basic sizes
`define OPSIZE		[7:0]
`define STATE		[3:0]
`define WORD		[15:0]
`define MEMSIZE 	[65535:0]	// Total amount of instructions in memory
`define REGSIZE 	[15:0]		// Number of Registers
`define DEST		[15:0]

//Instruction Field Placements
`define OP		[15:8]
`define Op0		[15:12]
`define Op1		[11:8]
`define Reg0		[3:0]
`define Reg1		[7:4]
`define Imm8		[11:4]
`define HighBits	[15:8]
`define LowBits		[7:0]

// 4 bit op codes
`define LdOrSt		4'h4
`define TrapOrJr	4'h0
`define OPci8		4'hb
`define OPcii		4'hc
`define OPcup		4'hd
`define OPbz		4'he
`define OPbnz		4'hf

// 8 bit op codes
`define OPtrap		8'h00
`define OPjr 		8'h01
`define OPnop		8'h02
`define OPld		8'h40
`define OPst		8'h41

// ALU
`define OPnot		8'h10
`define OPanyi		8'h30
`define OPanyii		8'h31
`define OPnegi		8'h32
`define OPnegii		8'h33
`define OPand		8'h50
`define OPor		8'h51
`define OPxor		8'h52
`define OPdup		8'h53
`define OPaddi		8'h70
`define OPaddii		8'h71
`define OPmuli		8'h72
`define OPmulii		8'h73
`define OPshi		8'h74
`define OPshii		8'h75
`define OPslti		8'h76
`define OPsltii		8'h77

// FPU
`define OPi2f		8'h20
`define OPii2pp		8'h21
`define OPf2i		8'h22
`define OPpp2ii		8'h23
`define OPinvf		8'h24
`define OPinvpp		8'h25
`define OPf2pp		8'h26
`define OPpp2f		8'h27
`define OPnegf		8'h28
`define OPaddf		8'h60
`define OPaddpp		8'h61
`define OPmulf		8'h62
`define OPmulpp		8'h63

`define NOP		16'b0000001000000001

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
	
	always @* begin
		case (op)
			//Math
			`OPaddf: out = addfOut;
			// commented out 16-bit table usage, as it causes INSANE compile times. Approx. 2 minutes with 1 item enabled, 6 minutes when 2 of the 3 items are enabled, and about 9 when all three are enabled.
			/*
			`OPaddpp: 
				begin 
					out`HighBits = table16[{rd`HighBits,rs`HighBits}][23:16];
					out`LowBits = table16[{rd`LowBits,rs`LowBits}] [23:16];
					#1$display("addpp %h, %h = %h",rd,rs,out);
				end
			`OPf2pp: 
				begin
					out`HighBits = table16[rd][7:0];
					out`LowBits = table16[rd][7:0];
					#1$display("f2pp %h, %h = %h",rd,rs,out);
				end
			`OPmulpp: 
				begin
					out`HighBits = table16[{rd`HighBits,rs`HighBits}][15:8];
					out`LowBits = table16[{rd`LowBits,rs`LowBits}] [15:8];
					#1$display("mulpp %h, %h = %h",rd,rs,out);
				end
				*/
			`OPmulf:
				begin
					out = mulfOut;
					#1$display("mulf %h, %h = %h",rd,rs,out);
				end
			`OPnegf: 
				begin
					// negate MSB of rd and concatenate with rest of rd
					out = {~rd[15], rd[14:0]};
					#1$display("negf %h = %h",rd,out);
				end
			`OPinvf: 
				begin
					out = invfOut;
					#1$display("invf %h = %h",rd,out);
				end
			`OPinvpp: 
				begin
					out = {table8[rd `HighBits][39:32], table8[rd `LowBits][39:32]};
					#1$display("invpp %h, %h = %h",rd,rs,out);
				end
			
			//Conversion
			`OPf2i: 
				begin 
					out = f2iOut;
					#1$display("f2i %h = %h",rd,out);
				end
			`OPi2f: 
				begin
					out = i2fOut;
					#1$display("i2f %h = %h",rd,out);
				end
			`OPii2pp: 
				begin
					out = {table8[rd `HighBits][7:0], table8[rd `LowBits][7:0]};
					#1$display("ii2pp %h = %h",rd,out);
				end
			`OPpp2f: 
				begin
					out = table8[rd `LowBits][31:16];
					#1$display("pp2f %h = %h",rd,out);
				end
			`OPpp2ii: 
				begin
					out = {table8[rd `HighBits][15:8], table8[rd `LowBits][15:8]};
					#1$display("pp2ii %h = %h",rd,out);
				end
			default: begin end
		endcase
	end
	
endmodule


module alu(rd, rs, op, aluOut);
	input `WORD rd;
	input wire `WORD rs;
	input wire `OPSIZE op;
	output wire `WORD aluOut;
	
	
	reg `WORD out;
	assign aluOut = out;
	
	//These are the operations 
	always @* begin 
		case (op)
			`OPaddi:  begin out = rd `WORD + rs `WORD; end
			
			`OPaddii: begin
				out `HighBits = rd `HighBits + rs `HighBits; 
				out `LowBits = rd `LowBits + rs `LowBits;
			end
			`OPmuli: begin out = rd `WORD * rs `WORD; end
			`OPmulii: begin 
				out `HighBits = rd `HighBits * rs `HighBits; 
				out `LowBits = rd `LowBits * rs `LowBits; 
			end
			`OPshi: begin out = ((rs `WORD > 0) ? (rd `WORD << rs `WORD) : (rd[15:0] >> -rs[15:0])); end
			`OPshii: begin 
				out `HighBits = ((rs `HighBits >0)?(rd `HighBits <<rs `HighBits):(rd `HighBits >>-rs `HighBits ));
				out `LowBits = ((rs `LowBits >0)?(rd `LowBits <<rs `LowBits):(rd `LowBits >>-rs `LowBits ));
			end
			`OPslti: begin out = rd `WORD < rs `WORD; end
			`OPsltii: begin 
				out `HighBits= rd `HighBits < rs `HighBits; 
				out `LowBits = rd `LowBits < rs `LowBits; 
			end

			`OPand: begin out = rd & rs; end
			`OPor: begin out = rd | rs; end
			`OPxor: begin out = rd ^ rs; end
			`OPanyi: begin out = (rd ? -1: 0); end
			`OPanyii: begin 
				out `HighBits= (rd `HighBits ? -1 : 0); 
				out `LowBits = (rd `LowBits ? -1 : 0); 
			end
			`OPnegi: begin out = -rd; end
			`OPnegii: begin 
				out `HighBits = -rd `HighBits; 
				out `LowBits = -rd `LowBits; 
			end
			`OPnot: begin out = ~rd; end
			`OPdup: begin 
				#1$display("dup %h, %h", rd, rs);
				out = rs; end
		endcase	
	end
endmodule

module processor(halt, reset, clk);
	//control signal definitions
	output reg halt;
	input reset, clk;
	reg `STATE s;
	reg `OPSIZE op;

	//processor component definitions
	reg `WORD text `MEMSIZE;		// instruction memory
	reg `WORD data `MEMSIZE;		// data memory
	reg `WORD pc = 0;
	reg `WORD ir;
	reg `WORD regfile `REGSIZE;		// Register File Size
	wire `WORD aluOut, fpuOut;
	reg `DEST target;	// jump target
	//new variables
	reg jump;
	reg `WORD ir0, ir1;
	reg `WORD rd1, rs1;
	reg `WORD imm, res;
	reg `WORD tpc, pc1, pc0;
	wire pendpc;		// is there a pc update
	reg wait1;		// is a stall needed in stage 1

	alu myalu(rd1, rs1, op, aluOut);
	fpu myfpu(rd1, rs1, op, fpuOut);
	
	//processor initialization
	always @(posedge reset) begin
		halt = 0;
		pc = 0;
		pc0 = 0;
		pc1 = 0;
		//state is NOP
		s = `TrapOrJr;
		jump = 0;
		rd1 = 0;
		rs1 = 0;
		ir0 = `NOP;
		ir1 = `NOP;
		
		//The following functions read from VMEM?
		`LOADTEXT;
		`LOADDATA;
		//$readmemh2(table16);
		//$readmemh3(table8);
	end
	
	//checks if the destination register is set
	function setsrd;
	input `WORD inst;
	setsrd = (inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz) && (inst `OP != `OPst) && (inst `OP != `OPtrap) 
		&& (inst `OP != `OPnop);
	endfunction
	
	//checks if pc is set
	function setspc;
	input `WORD inst;
		setspc = !((inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz));
	endfunction
	
	//check if rd is used
	function usesrd;
	input `WORD inst;	
	usesrd = (inst `OP != `OPld) && (inst `OP != `OPtrap) && (inst `OP != `OPci8) && (inst `OP != `OPcii) && (inst `OP != `OPcup) 
		&& (inst `OP != `OPnop);
	endfunction
	
	//check if rd is used
	function usesrs;
	input `WORD inst;
		usesrs = !((inst `OP != `OPaddi) && (inst `OP != `OPaddii) && (inst `OP != `OPaddf) && (inst `OP != `OPaddpp) && 
			(inst `OP != `OPld) && (inst `OP != `OPand) && (inst `OP != `OPmuli) && (inst `OP != `OPmulii) && 
			(inst `OP != `OPmulf) && (inst `OP != `OPmulpp) && (inst `OP != `OPshi) && (inst `OP != `OPshii) && 
		   	(inst `OP != `OPslti) && (inst `OP != `OPst) && (inst `OP != `OPxor));
	endfunction
	
	//is pc changing
	assign pendpc = (setspc(ir0) || setspc(ir1));
	
	//start of state 0
	always @(posedge clk) begin
		tpc = (jump ? target : pc);
		if ((ir0 != `NOP) && setsrd(ir1) && 
		   ((usesrd(ir0) && (ir0 `Reg0 == ir1 `Reg0)) || (usesrs(ir0) && (ir0 `Reg1 == ir1 `Reg0)))) begin
    			// blocked by stage 1, so don't increment
   			pc <= tpc;
  		end else begin
   			// not blocked by stage 1
  			ir = text[tpc];
			if(pendpc) begin
				ir0 <= `NOP;
     				pc <= tpc;
			end else begin
				ir0 <= ir;
				pc <= tpc + 1;
			end
		end
		pc0 <= tpc;
	end
	
	//start of stage 1
	always @(posedge clk) begin
		if((ir0 != `NOP) && setsrd(ir1) && 
		   ((usesrd(ir0) && (ir0 `Reg0 == ir1 `Reg0)) || (usesrs(ir0) && (ir0 `Reg1 == ir1 `Reg0)))) begin
			wait1 = 1;
			ir1 <= `NOP;
		//no conflict
		end else begin
			wait1 = 0;
			rd1 <= regfile[ir0 `Reg0];
			rs1 <= regfile[ir0 `Reg1];
			ir1 <= ir0;
			op <= {ir0 `Op0, ir0 `Op1};
			s  <= ir0 `Op0;
		end
		pc1 <= pc0;
	end
	
	//stage 2 starts here
	always @(posedge clk) begin
		//State machine case
		case (s)
			`TrapOrJr: begin
				case (op)
					`OPtrap: 
						begin
							halt <= 1;
						end
					`OPjr:
						begin
							target <= rd1;
							jump <= 1;
						end
					`OPnop:
						begin
							jump <= 0;
						end
				endcase
			 end // halts the program and saves the current instruction
			`LdOrSt:
				begin
					case (op)
						`OPld:
							begin
								regfile [ir1 `Reg0] <= data[rs1];
								jump <= 0;
							end
						`OPst:
							begin
								data[regfile [ir1 `Reg1]] = rd1;
								jump <= 0;
							end
					endcase
				end
			`OPci8:
				begin
					regfile [ir1 `Reg0] <= {{8{ir1[7]}} ,ir1 `Imm8};
					jump <= 0;
					//#1$display("",)
				end
			`OPcii:
				begin
					regfile [ir1 `Reg0] `HighBits <= ir1 `Imm8;
					regfile [ir1 `Reg0] `LowBits <= ir1 `Imm8;
					jump <= 0;
				end
			`OPcup:
				begin
					regfile [ir1 `Reg0] `HighBits <= ir1 `Imm8;
					jump <= 0;
				end
			`OPbz:
				begin
					if (rd1 == 0) begin
						target <= pc1 + ir1 `Imm8;
						jump <= 1;
					end
				end
			`OPbnz:
				begin
					if (rd1 != 0) begin
						target <= pc1 + ir1 `Imm8;
						jump <= 1;
					end
				end
			default: //default cases are handled by ALU or FPU
				begin
					if (((op >= `OPi2f) && (op <= `OPnegf)) || ((op >= `OPaddf) && (op <= `OPmulpp)))
						begin
							//$display("opcode %h, entering FPU",op);
							regfile[ir1 `Reg0] <= fpuOut;
						end
					else 
						regfile[ir1 `Reg0] <= aluOut;
					
					jump <= 0;
				end
		endcase	
	end
endmodule 

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  `DUMP;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
