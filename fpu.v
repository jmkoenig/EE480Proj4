module fpu(rd,rs,op,fpuOut);
	$readmemh2(table16);
	$readmemh3(table8);
	reg [23:0] table16[65535:0]
	reg [39:0] table8[255:0]
	
	always @* begin
		case (op)
			//Math
			`OPaddf: fpuOut <= table16[
			`OPaddpp: fpuOut <= table16[{rd,rs}][23:16];
			`OPmulf: 
			`OPmulpp: fpuOut <= table16[{rd,rs}][15:8];
			`OPnegf:
			`OPinvf: 
			`OPinvpp:
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