module fpu(rd,rs,op,fpuOut);
	$readmemh2(table16);
	$readmemh3(table8);
	reg [23:0] table16[65535:0]
	reg [39:0] table8[255:0]
	
	always @* begin
		case (op)
			//Math
			`OPaddf: 
			`OPaddpp: 
			`OPmulf: 
			`OPmulpp: 
			`OPnegf:
			`OPinvf: 
			`OPinvpp:
			//Conversion
			`OPf2i:
			`OPf2pp:
			`OPi2f: 
			`OPii2pp: 
			`OPpp2f: 
			`OPpp2ii: 
		endcase
	end
endmodule