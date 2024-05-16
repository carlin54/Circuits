module dffrs_tb;
    reg d;
    reg e;
    reg r;
    reg s;
    reg clk;
    wire q;

    dffrs DUT (
        .d(d),
        .clk(clk),
        .e(e),
        .r(r),
        .s(s),
        .q(q)
    );

    task expect;
        input eq;
        if (eq !== q) begin
            $display("FAIL: (e, %b), (d, %b), (r, %b), (s, %b), (q, %b), (expected, %b)", e, d, r, s, q, eq);
        end
    endtask

    initial begin
		e = 0; d = 0; r = 0; s = 0; clk=1; #100; clk=0; expect(0);
		e = 0; d = 0; r = 0; s = 1; clk=1; #100; clk=0; expect(1);
        e = 0; d = 0; r = 1; s = 0; clk=1; #100; clk=0; expect(0);
        e = 0; d = 1; r = 0; s = 0; clk=1; #100; clk=0; expect(0);
        e = 1; d = 1; r = 0; s = 0; clk=1; #100; clk=0; expect(1);
        e = 1; d = 0; r = 0; s = 1; clk=1; #100; clk=0; expect(1);
        e = 1; d = 0; r = 0; s = 0; clk=1; #100; clk=0; expect(0);
        e = 1; d = 0; r = 1; s = 1; clk=1; #100; clk=0; expect(0);
    end

endmodule
