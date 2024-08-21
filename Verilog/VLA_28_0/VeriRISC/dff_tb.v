module dff_tb;
    reg clk;
	reg d;
    wire q;

    dff DUT (
        .clk(clk),
        .d(d),
        .q(q)
    );

    task expect;
        input expected;
		if (q !== expected) begin
			$display("FAIL: (d, %b), (q, %b), (expected, %b)", d, q, expected);
		end
    endtask

    initial begin
		expect(0);
		d=0; clk=1; #100; clk=0; expect(0);
		d=1; clk=1; #100; clk=0; expect(1);

		clk=1; #100; clk=0; expect(1);
		clk=1; #100; clk=0; expect(1);
		clk=1; #100; clk=0; expect(1);

		d=0; clk=1; #100; clk=0; expect(0);

    end


endmodule
