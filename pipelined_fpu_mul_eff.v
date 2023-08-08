module pipelined_fpu_mul_eff
(
	input clk, rst,
	input [31:0] a, b,
	output [31:0] s
);
	wire a_expo_is_00 = ~|a[30:23];
	wire a_expo_is_ff = &a[30:23];
	wire a_frac_is_00 = ~|a[22:0];
	wire a_is_inf = a_expo_is_ff & a_frac_is_00;
	wire a_is_nan = a_expo_is_ff & ~a_frac_is_00;
	wire a_is_0 = a_expo_is_00 & a_frac_is_00;

	wire b_expo_is_00 = ~|b[30:23];
	wire b_expo_is_ff = &b[30:23];
	wire b_frac_is_00 = ~|b[22:0];
	wire b_is_inf = b_expo_is_ff & b_frac_is_00;
	wire b_is_nan = b_expo_is_ff & ~b_frac_is_00;
	wire b_is_0 = b_expo_is_00 & b_frac_is_00;

	wire [22:0] nan_frac = (a[21:0] > b[21:0]) ? {1'b1, a[21:0]} : {1'b1, b[21:0]};
	wire is_nan = a_is_nan | b_is_nan | (a_is_inf & b_is_0) | (b_is_inf & a_is_0);
	wire [23:0] a_frac24 = {~a_expo_is_00, a[22:0]};
	wire [23:0] b_frac24 = {~b_expo_is_00, b[22:0]};
	wire [35:0] pp1 = a_frac24 * b_frac24[11:0];

	reg sign_str, s_is_nan_str, s_is_inf_str;
	reg [9:0] exp10_str;
	reg [22:0] inf_nan_frac_str;
	reg [23:0] a_frac24_str;
	reg [11:0] b_frac24_msb_str;
	reg [35:0] pp1_str;

	always @(posedge clk) begin
		if (rst) begin
			sign_str <= 0;
			s_is_nan_str <= 0;
			s_is_inf_str <= 0;
			exp10_str <= 0;
			inf_nan_frac_str <= 0;
			a_frac24_str <= 0;
			b_frac24_msb_str <= 0;
			pp1_str <= 0;
		end else begin
			sign_str <= a[31] ^ b[31];
			s_is_nan_str <= is_nan;
			s_is_inf_str <= a_is_inf | b_is_inf;
			exp10_str <= {2'h0, a[30:23]} + {2'h0, b[30:23]} - 10'h7f + a_expo_is_00 + b_expo_is_00;
			inf_nan_frac_str <= is_nan ? nan_frac : 23'h0;
			a_frac24_str <= a_frac24;
			b_frac24_msb_str <= b_frac24[23:12];
			pp1_str <= pp1;
		end
	end
	
	wire [35:0] pp2 = a_frac24_str * b_frac24_msb_str;
	wire [87:0] full_z = pp1_str + {pp2, 12'h000};
	reg sign, s_is_nan, s_is_inf;
	reg [9:0] exp10;
	reg [22:0] inf_nan_frac;
	reg [47:8] z_sum, z_carry;
	reg [7:0] z_7_0;

	always @(posedge clk) begin
		if (rst) begin
			sign <= 0;
			s_is_nan <= 0;
			s_is_inf <= 0;
			exp10 <= 0;
			inf_nan_frac <= 0;
			z_carry <= 0;
			z_sum <= 0;
			z_7_0 <= 0;
		end else begin
			sign <= sign_str;
			s_is_nan <= s_is_nan_str;
			s_is_inf <= s_is_inf_str;
			exp10 <= exp10_str;
			inf_nan_frac <= inf_nan_frac_str;
			z_carry <= full_z[87:48];
			z_sum <= full_z[47:8];
			z_7_0 <= full_z[7:0];
		end
	end

	wire [47:8] z_47_8 = {1'b0, z_sum} + z_carry;
	wire [47:0] z = {z_47_8, z_7_0};

	wire [46:0] z5, z4, z3, z2, z1, z0;
	wire [5:0] zeros;
	
	assign zeros[5] = ~|z[46:15];
	assign z5 = zeros[5] ? {z[14:0], 32'b0} : z[46:0];
	assign zeros[4] = ~|z5[46:31];
	assign z4 = zeros[4] ? {z5[30:0], 16'b0} : z5;
	assign zeros[3] = ~|z4[46:39];
	assign z3 = zeros[3] ? {z4[38:0], 8'b0} : z4;
	assign zeros[2] = ~|z3[46:43];
	assign z2 = zeros[2] ? {z3[42:0], 4'b0} : z3;
	assign zeros[1] = ~|z2[46:45];
	assign z1 = zeros[1] ? {z2[44:0], 2'b0} : z2;
	assign zeros[0] = ~z1[46];
	assign z0 = zeros[0] ? {z1[45:0], 1'b0} : z1;

	reg [46:0] frac0;
	reg [9:0] exp0;

	always @(*) begin
		if (z[47]) begin
			exp0 = exp10 + 10'h1;
			frac0 = z[47:1];
		end else begin
			if (!exp10[9] && (exp10[8:0] > zeros) && z0[46]) begin
				exp0 = exp10 - zeros;
				frac0 = z0;
			end else begin
				exp0 = 0;
				if (!exp10[9] && (exp10 != 0))
					frac0 = z[46:0] << (exp10 - 10'h1);
				else
					frac0 = z[46:0] >> (10'h1 - exp10);
			end
		end
	end

	wire [26:0] frac = {frac0[46:21], |frac0[20:0]};
	wire frac_plus_1 = frac0[2] & (frac0[1] | frac0[0]) | frac0[2] & ~frac0[1] & ~frac0[0] & frac0[3];
	wire [24:0] frac_round = {1'b0, frac[26:3]} + frac_plus_1;
	wire [9:0] exp1 = frac_round[24] ? exp0 + 10'h1 : exp0;
	wire overflow = (exp0 >= 10'h0ff) | (exp1 >= 10'h0ff);

	reg [31:0] prod;

	always @(posedge clk) begin
		if (rst) begin
			prod <= 0;
		end else begin
			prod <= final_result(overflow, sign, s_is_inf, s_is_nan, exp1[7:0], frac_round[22:0], inf_nan_frac);
		end
	end 
	
	assign s = prod;

	function [31:0] final_result;
		input overflow;
		input sign, s_is_inf, s_is_nan;
		input [7:0] exponent;
		input [22:0] fraction, inf_nan_frac;
		
		casex({overflow, sign, s_is_nan, s_is_inf})
			4'b1_x_0_x : final_result = {sign, 8'hff, 23'h000000};
			4'b0_x_0_0 : final_result = {sign, exponent, fraction};
			4'bx_x_1_x : final_result = {1'b1, 8'hff, inf_nan_frac};
			4'bx_x_0_1 : final_result = {sign, 8'hff, inf_nan_frac};
			default : final_result = {sign, 8'h00, 23'h000000};
		endcase
	endfunction

endmodule