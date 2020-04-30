// Defines
// some basic sizes of things
`define DATA	[15:0]
`define ADDR	[15:0] //address
`define INST	[15:0] //instruction
`define SIZE	[65535:0]
`define STATE	[7:0]  //state number size & opcode size
`define REGS	[15:0] //size of registers
`define REGNAME	[3:0]  //16 registers to choose from
`define WORD	[15:0] //16-bit words
`define HALF	[7:0]	//8-bit half-words
`define NIB		[3:0]	//4-bit nibble
`define HI8		[15:8]
`define LO8		[7:0]
`define HIGH8	[15:8]
`define LOW8	[7:0]

// the instruction fields
`define F_H		[15:12] //4-bit header (needed for short opcodes)
`define F_OP	[15:8]
`define F_D		[3:0]
`define F_S		[7:4]
`define F_C8	[11:4]
`define F_ADDR	[11:4]

// lengths
`define WORD_LENGTH 16;

//long instruction headers
`define HCI8	4'hb
`define HCII	4'hc
`define HCUP	4'hd
`define HBNZ	4'hf
`define HBZ		4'he

// opcode values, also state numbers
`define OPADDI	8'h70
`define OPADDII	8'h71
`define OPMULI	8'h72
`define OPMULII	8'h73
`define OPSHI	8'h74
`define OPSHII	8'h75
`define OPSLTI	8'h76
`define OPSLTII	8'h77

`define OPADDP	8'h60
`define OPADDPP	8'h61
`define OPMULP	8'h62
`define OPMULPP	8'h63

`define OPAND	8'h50
`define OPOR	8'h51
`define OPXOR	8'h52

`define OPLD	8'h40
`define OPST	8'h41

`define OPANYI	8'h30
`define OPANYII	8'h31
`define OPNEGI	8'h32
`define OPNEGII	8'h33

`define OPI2P	8'h20
`define OPII2PP	8'h21
`define OPP2I	8'h22
`define OPPP2II	8'h23
`define OPINVP	8'h24
`define OPINVPP	8'h25

`define OPNOT	8'h10

`define OPJR	8'h01

`define OPTRAP	8'h00

`define OPCI8	8'hb0
`define OPCII	8'hc0
`define OPCUP	8'hd0

`define OPBZ	8'he0
`define OPBNZ	8'hf0

`define NOP 16'hffff

// state numbers (unused op codes)
`define IF	8'h96
`define ID	8'h97
`define EXMEM 8'h98
`define WB 8'h99

module processor(halt, reset, clk);
    output reg halt;
    input reset, clk;

    reg `DATA r `REGS;	// register file
    reg `DATA dm `SIZE;	// data memory
    reg `INST im `SIZE;	// instruction memory
    reg `INST ir;
	reg `INST ir0;
    reg `STATE op0;
    reg `NIB head;		// current header (1st half of opcode)
    reg `REGNAME d0;	// destination register name
    reg `REGNAME s0; //source register name
    reg `DATA src;		// src value
    reg `DATA target;	// target for branch or jump
    reg `ADDR pc;
    reg `LOW8 imm;
	reg stage0_bz, stage0_bnz, stage0_jr;

    // Reset logic
    always @ (reset) begin
        halt = 0;
        pc = 0;
		ir = `NOP;
		ir0 = `NOP;
		ir1 = `NOP;
		ir2 = `NOP;
		ir3 = `NOP;
		stage0_jr = 0;
		stage0_bnz = 0;
		stage0_bz = 0;
		stage1_jr = 0;
		stage1_bnz = 0;
		stage1_bz = 0;
		rd2 = 0;
		op1 = 0;
		op2 = 0;
		res = 0;
		haltsignal = 0;
		
        $readmemh("vmem0.text", im); // Instruction memory
        $readmemh("vmem1.data", dm); // Data memory
		
    end
    
	// Check for Trap
	function istrap;
	input `INST inst;
	istrap = ((inst `F_OP == `OPTRAP));
	endfunction
	
	function setsrd;
	input `INST inst;
	setsrd = ((inst `F_H != `OPBNZ) && (inst `F_H != `OPBZ) && (inst `F_OP != `OPJR) && (inst `F_OP != `OPST));
	endfunction
	
	function usesrs;
	input `INST inst;
	usesrs = (inst `F_OP != `OPANYI) && (inst `F_OP != `OPANYII) && (inst `F_H != `HBNZ) && (inst `F_H != `HBZ) && (inst `F_H != `HCI8) && (inst `F_H != `HCII) && (inst `F_H != `HCUP) && (inst `F_OP != `OPI2P) && (inst `F_OP != `OPII2PP) && (inst `F_OP != `OPINVP) && (inst `F_OP != `OPINVPP) && (inst `F_OP != `OPJR) && (inst `F_OP != `OPNEGI) && (inst `F_OP != `OPNEGII) && (inst `F_OP != `OPNOT) && (inst `F_OP != `OPP2I) && (inst `F_OP != `OPPP2II);
	endfunction
	
	reg haltsignal; // Signal to tell IF to never fetch anything new
	
    // 0. IF/ID Stage
    always @ (posedge clk) begin
	
		ir = im[pc];
		head = ir `F_H;
		
		//$display("IF stage: %d, %d", pc, wait1);
		// Check if new PC counter exists
		
		pc <= (wait1 == 1) ? (pc1) : (pc+1);
		
		if (wait1 == 1) begin
		$display("Branch to %d",pc1);
		ir0 <= `NOP;
		end
		
		else begin
		// Check for Trap
		if (istrap(ir) || (haltsignal == 1)) begin
			haltsignal <= 1;
			ir0 <= ir;
			op0 <= `OPTRAP;
		end
		
		else begin
		case(head)
			`HCI8: op0 <= `OPCI8;
			`HCII: op0 <= `OPCII;
			`HCUP: op0 <= `OPCUP;
			`HBNZ: op0 <= `OPBNZ;
			`HBZ: op0 <= `OPBZ;
			default: begin
				op0 <= ir `F_OP;
				s0 <= ir `F_S;
			end
			endcase
			
		stage0_jr <= (ir `F_OP == `OPJR);
		stage0_bnz <= (ir `F_OP == `OPBNZ);
		stage0_bz <= (ir `F_OP == `OPBZ);
		//$display("JR: %d, BNZ: %d, BZ: %d",stage0_jr,stage0_bnz,stage0_bz);
		ir0 <= ir;
		end
		end
		
	end
	
	
	reg `INST ir1;
	reg `STATE op1;
	reg `REGS rd1;
	reg `REGS rs1;
	reg `REGS rd;
	reg `REGS rs;
	reg stage1_bz, stage1_bnz, stage1_jr;
	wire wait1;
	reg [15:0] pc1;
	
	//assign pc1 = (stage0_jr) ? (rd) : (pc + ir0 `F_C8);
	assign wait1 = (stage1_bz) || (stage1_bnz) || (stage1_jr);
	
    // 1. Read Stage
    always @ (posedge clk) begin
	// Add the transfer of the immediate value
		
		pc1 <= (stage0_jr) ? (rd) : (pc - 1 + ir0 `F_C8);
		stage1_jr <= stage0_jr;
		if (rd == 0 && stage0_bz) begin
		stage1_bz <= 1;
		stage1_bnz <= 0;
		ir1 <= `NOP;
		op1 <= 255;
		end else if (rd != 0 && stage0_bnz) begin
		stage1_bz <= 0;
		stage1_bnz <= 1;
		ir1 <= `NOP;
		op1 <= 255;
		end else begin
		stage1_bz <= 0;
		stage1_bnz <= 0;
		ir1 <= ir0;
		op1 <= op0;
		end
		
		//$display("Read stage: %d, RD: %h, RS: %h", pc, ir0 `F_D, ir0 `F_S);
		if (wait1 == 1) begin
			ir1 <= `NOP;
		end
		
		else begin
		
		if (Ex_to_Rd_Signal == 1) begin
		//$display("Ex Forward Rd on %d: %h",ir0 `F_D,Ex_to_Read);
		//$display("Res @ time: %h",res);
		rd = Ex_to_Read;
		end
		else if (WB_to_Rd_Signal == 1) begin
		//$display("WB Forward Rd on %d: %h",ir0 `F_D,WB_to_Read);
		//$display("Res @ time: %h",res);
		rd = WB_to_Read;
		end
		else begin
		rd = r[ir0 `F_D];
		end
		
		
		if (Ex_to_Rs_Signal == 1 && usesrs(ir0)) begin
		//$display("Ex Forward Rs on %d: %h",ir0 `F_S,Ex_to_Read);
		//$display("Res @ time: %h",res);
		rs = Ex_to_Read;
		end 
		else if (WB_to_Rs_Signal == 1 && usesrs(ir0)) begin
		//$display("WB Forward Rs on %d: %h",ir0 `F_D,WB_to_Read);
		//$display("Res @ time: %h",res);
		rs = WB_to_Read;
		end
		else begin
		rs = r[ir0 `F_S];
		end
		
		rd1 <= rd;
		rs1 <= rs;
		end
		// Handle the branches and the jump
		//
    end
	
	reg `INST ir2;
	reg `REGS rd2;	// Register data
	//reg `REGS rs2;	// Register data
	reg `STATE op2;
	reg `WORD res;
	wire Ex_to_Rd_Signal;
	wire Ex_to_Rs_Signal;
	wire [15:0] Ex_to_Read;
	
	assign Ex_to_Rd_Signal = (ir1 `F_D == ir0 `F_D) && (ir1 != `NOP && ir0 != `NOP) && setsrd(ir1);
	assign Ex_to_Rs_Signal = (ir1 `F_D == ir0 `F_S) && (ir1 != `NOP && ir0 != `NOP) && setsrd(ir1) && usesrs(ir0);
	assign Ex_to_Read = res;
	
	// Always without pos/neg edge???
	// Or straight combinatorial
	always @ (negedge clk) begin
	case(op1)
            `OPCI8: begin
                res = ir1 `F_C8;
                if(ir1[11:11] == 1)
                    res `HI8 = 255;
                else
                    res `HI8 = 0;
				$display("OPCI8: %d, %d, %h",ir1 `F_D,ir1 `F_ADDR, res);
                end
            `OPCII: begin
                res = ir1 `F_C8;
                res `HI8 = ir1 `F_C8;
				$display("OPCII: %d, %d, %h",ir1 `F_D,ir1 `F_ADDR, res);
                end
			`OPCUP: begin
				res`LO8 = rd1`LO8;
				res`HI8 = ir1 `F_C8;
				$display("cup, $%d = %H", ir1 `F_D, res);
				end
            `OPADDI, `OPADDP: begin
			res = rd1 + rs1;
			$display("OPADDI/P: %d: %h, %d: %h, %h",ir1 `F_D,rd1,ir1 `F_S,rs1, res);
			end
            `OPADDII, `OPADDPP: begin
                res = rd1 + rs1;
                res `HI8 = rd1 `HI8 + rs1 `HI8;
				$display("OPADDII/PP: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
                end
            `OPMULI, `OPMULP: begin
			res = rd1 * rs1;
			$display("OPMULI/P: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
			end
            `OPMULII, `OPMULPP: begin
                res = rd1 * rs1;
                res `HI8 = rd1 `HI8 * rs1 `HI8;
				$display("OPMULII/PP: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
                end
            `OPSHI: begin
			res = (rs1 > 32767 ? rd1 >> -rs1 : rd1 << rs1);
			$display("OPSHI: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
			end
            `OPSHII: begin
                res `LOW8 = (rs1 `LOW8 > 127 ? rd1 `LOW8 >> -rs1 `LOW8 : rd1 `LOW8 << rs1 `LOW8);
                res `HI8 = (rs1 `HI8 > 127 ? rd1 `HI8 >> -rs1 `HI8 : rd1 `HI8 << rs1 `HI8);
				$display("OPSHII: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
                end
            `OPAND: begin
			res = rd1 & rs1;
			$display("OPAND: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
			end
            `OPOR: begin
			res = rd1 | rs1;
			$display("OPOR: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
			end
            `OPXOR: begin
			res = rd1 ^ rs1;
			$display("OPXOR: %d, %d, %h",ir1 `F_D,ir1 `F_S, res);
			end
            `OPNOT: begin
			res = ~rd1;
			$display("OPNOT: %d, %h",ir1 `F_D, res);
			end
            `OPANYI: begin
			res = (rd1 ? -1 : 0);
			$display("OPANYI: %d, %h",ir1 `F_D, res);
			end
            `OPANYII: begin
                res `HI8 = (rd1 `HI8 ? -1 : 0);
                res `LOW8 = (rd1 `LOW8 ? -1 : 0);
				$display("OPANYII: %d, %h",ir1 `F_D, res);
                end
            `OPNEGI: begin 
			res = -rd1;
			$display("OPNEGI: %d, %h",ir1 `F_D, res);
			end
            `OPNEGII: begin
                res `HI8 = -rd1 `HI8;
			    res `LOW8 = -rd1 `LOW8;
				$display("OPNEGII: %d, %h",ir1 `F_D, res);
                end
            `OPST: begin
			dm[rs1] = rd1;
			$display("OPST: %d",ir1 `F_D);
			end
            `OPLD: begin
			res = dm[rs1];
			$display("OPLD: %d",ir1 `F_D);
			end
			`OPSLTI: begin
			res = rd1 < rs1;
			$display("OPSLTI: %d, %d, %h",ir1 `F_D, ir1 `F_S, res);
			end
			`OPSLTII: begin 
                res `HIGH8 = rd1 `HIGH8 < rs1 `HIGH8; 
			    res `LOW8 = rd1 `LOW8 < rs1 `LOW8;
				$display("OPSLTII: %d, %d, %h",ir1 `F_D, ir1 `F_S, res);
                end
			`OPI2P: begin 
				res <= rd1;
				$display("OPI2P: $%d, %h", ir1 `F_D, res);
				end
			`OPII2PP: begin
				res `HI8 <= rd1 `HI8;
				res `LO8 <= rd1 `LO8;
				$display("OPII2PP: $%d, %h", ir1 `F_D, res);
				end
			`OPP2I: begin 
				res <= rd1;
				$display("OPP2I: $%d, %h", ir1 `F_D, res);
				end
			`OPPP2II: begin
				res `HI8 <= rd1 `HI8;
				res `LO8 <= rd1 `LO8;
				$display("OPPP2II: $%d, %h", ir1 `F_D, res);
				end
			`OPINVP: begin 
				res <= (rd1 == 1 ? 1 : 0);
				$display("OPINVP: $%d, %h", ir1 `F_D, res);
				end
			`OPINVPP: begin 
				res `HI8 <= (rd1 `HI8 == 1 ? 1 : 0);
				res `LO8 <= (rd1 `LO8 == 1 ? 1 : 0);
				$display("OPINVPP: $%d, %h", ir1 `F_D, res);
				end
            default: begin
			res = rd1;
			//$display("Default?");
			end
        endcase
		end
	// Ex Stage
	always @ (posedge clk) begin
		
	//$display("Ex stage: %d, %h, %h, %h, %h", pc, ir1, op1, rs1, rd1);
	
		ir2 <= ir1;
		if (ir1 != `NOP && ir1 `F_OP != `OPTRAP) begin
		//$display("Res Taken");
		rd2 <= res;
		end
	end
	
	reg `INST ir3;
	reg `REGS rd3;	// Register data
	wire WB_to_Rd_Signal;
	wire WB_to_Rs_Signal;
	wire [15:0] WB_to_Read;
	
	assign WB_to_Rd_Signal = (ir2 `F_D == ir0 `F_D) && (ir2 != `NOP && ir0 != `NOP) && setsrd(ir2);
	assign WB_to_Rs_Signal = (ir2 `F_D == ir0 `F_S) && (ir2 != `NOP && ir0 != `NOP) && setsrd(ir2) && usesrs(ir0);
	assign WB_to_Read = rd2;
	
    // 3. WB Stage
	always @ (posedge clk) begin
	
	//$display("WB stage: %d", pc);
		ir3 <= ir2;
		rd3 <= rd2;
		if (setsrd(ir2) && ir2 != `NOP) begin
			r[ir2 `F_D] <= rd2;
			//$display("WB: %h to %d", rd2,ir2 `F_D);
		end
		
		if (istrap(ir2)) begin
		halt <= 1;
		end
		
	end

endmodule


module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
//$dumpfile;
//$dumpvars(0, PE);
  #10 reset = 1;
  #10 clk = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 0;
	$display("------- Clock--------");
    #10 clk = 1;
  end
  $finish;
end
endmodule