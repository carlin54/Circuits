module latchrs(
	input d,
	input e,
	input r,
	input s,
	output reg q
);
	initial begin
  		q = 0;
	end

    always @(posedge e or posedge r or posedge s)
    begin
		if (r === 1) begin
            q <= 0;
		end else if (s === 1) begin
            q <= 1;
		end else if (e === 1 && e !== 'x && d !== 'x) begin
            q <= d;
		end

    end
endmodule
