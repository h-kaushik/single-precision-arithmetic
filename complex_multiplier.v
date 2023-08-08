module complex_multiplier
(
	input clk, rst,
	input [31:0] x_real, x_imag, y_real, y_imag,
	output [31:0] xy_real, xy_imag
);
	wire [31:0] rr, ri, ir, ii;

	pipelined_fpu_mul_eff mrr(
		.clk(clk),
		.rst(rst),
		.a(x_real),
		.b(y_real),
		.s(rr)
	);

	pipelined_fpu_mul_eff mri(
		.clk(clk),
		.rst(rst),
		.a(x_real),
		.b(y_imag),
		.s(ri)
	);

	pipelined_fpu_mul_eff mir(
		.clk(clk),
		.rst(rst),
		.a(x_imag),
		.b(y_real),
		.s(ir)
	);

	pipelined_fpu_mul_eff mii(
		.clk(clk),
		.rst(rst),
		.a(x_imag),
		.b(y_imag),
		.s(ii)
	);

	fpu_adder realpart(
		.clk(clk),
		.rst(rst),
		.a(rr),
		.b(ii),
		.sub(1'b1),
		.s(xy_real)
	);

	fpu_adder imagpart(
		.clk(clk),
		.rst(rst),
		.a(ri),
		.b(ir),
		.sub(1'b0),
		.s(xy_imag)
	);
endmodule