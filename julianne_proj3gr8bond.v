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
`define LdOrSt		1'h4
`define TrapOrJr	1'h0
`define OPci8		1'hb
`define OPcii		1'hc
`define OPcup		1'hd
`define OPbz		1'he
`define OPbnz		1'hf

// 8 bit op codes
`define OPtrap		2'h00
`define OPjr 		2'h01
`define OPnop		2'h02
`define OPld		2'h40
`define OPst		2'h41

// ALU
`define OPnot		2'h10
`define OPanyi		2'h30
`define OPanyii		2'h31
`define OPnegi		2'h32
`define OPnegii		2'h33
`define OPand		2'h50
`define OPor		2'h51
`define OPxor		2'h52
`define OPdup		2'h53
`define OPaddi		2'h70
`define OPaddii		2'h71
`define OPmuli		2'h72
`define OPmulii		2'h73
`define OPshi		2'h74
`define OPshii		2'h75
`define OPslti		2'h76
`define OPsltii		2'h77

// FPU
`define OPi2f		2'h20
`define OPii2pp		2'h21
`define OPf2i		2'h22
`define OPpp2ii		2'h23
`define OPinvf		2'h24
`define OPinvpp		2'h25
`define OPf2pp		2'h26
`define OPpp2f		2'h27
`define OPnegf		2'h28
`define OPaddf		2'h60
`define OPaddpp		2'h61
`define OPmulf		2'h62
`define OPmulpp		2'h63

`define NOP		16'b0000001000000001

//Floating Point Stuff
`define FLOAT		[15:0]
`define FEXP		[14:7]	// exponent
`define FFRAC		[6:0]	// fractional part (leading 1 implied)
`define FSIGN		[15]	// sign bit


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


module fpu(rd,rs,op,fpuOut);
	input 'WORD rd;
	input wire 'WORD rs;
	input wire 'OPSIZE op;
	output wire 'WORD fpuOut
	$readmemh2(table16);
	$readmemh3(table8);
	reg [23:0] table16[65535:0]
	reg [39:0] table8a[255:0]
	reg [39:0] table8b[255:0]
	
	always @* begin
		case (op)
			//Math
			`OPaddf: 
			`OPaddpp: fpuOut <= table16[{rd,rs}][23:16];
			`OPmulf: 
			`OPmulpp: fpuOut <= table16[{rd,rs}][15:8];
			`OPnegf:
			`OPinvf: 
			`OPinvpp: fpuOut <= {table8a[rd[15:8]], table8b[rd[7:0]]};
			//Conversion
			`OPf2i:
			`OPf2pp: fpuOut <= table16[{rd,rs}][7:0];
			`OPi2f: 
			`OPii2pp: 
			`OPpp2f: 
			`OPpp2ii: 
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
		$readmemh0(text);
		$readmemh1(data);
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
					if ((op >= `OPi2f) && (op <= `OPnegf)) || ((op >= `OPaddf) && (op <= `OPmulpp))
						regfile [ir1 `Reg0] <= fpuOut;
					else
						regfile [ir1 `Reg0] <= aluOut;
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
  $dumpfile;
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
