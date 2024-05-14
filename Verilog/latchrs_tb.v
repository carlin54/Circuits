module latchrs_tb;
	reg d;
	reg e;
	reg r;
	reg s;
	wire q;

	latchrs DUT (.d(d), .e(e), .r(r), .s(s), .q(q));

	task expect(input eq);
		if (eq !== q) begin
			$display("FAIL: (e, %b), (d, %b), (r, %b), (s, %b), (q, %b), (expected, %b)", e, d, r, s, q, eq);
		end
	endtask


	initial begin
		e=0; 	d=0; 	r=0; s=0; #100; expect(0);
		e=0; 	d=0; 	r=0; s=1; #100; expect(1);
		e=0; 	d=0; 	r=1; s=0; #100; expect(0);
		e=0; 	d=1; 	r=0; s=0; #100; expect(0);
		e=1; 	d=1; 	r=0; s=0; #100; expect(1);
		e=1; 	d=0; 	r=0; s=1; #100; expect(1);
		e=1; 	d=0; 	r=0; s=1; #100; expect(1);
		e=1; 	d=0; 	r=1; s=1; #100; expect(0);
	end

endmodule
