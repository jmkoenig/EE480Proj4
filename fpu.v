module fpu(rd,rs,op,fpuOut);
	reg [23:0] a[65535:0]
	reg [23:0] b[65535:0]
	reg [39:0] c[255:0]
	reg [39:0] d[255:0]
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