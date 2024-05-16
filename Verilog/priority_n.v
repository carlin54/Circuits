module priority_n #(
    parameter WIDTH = 7
)(
    input wire [WIDTH-1:0] py,
    output reg [CLOG2_WIDTH-1:0] pa
);

    // Function to calculate ceil(log2(WIDTH))
    function integer clog2(input integer value);
        integer i;
        integer result;
        begin
            result = 0;
            value = value - 1;
            while (value > 0) begin
                value = value >> 1;
                result = result + 1;
            end
            clog2 = result;
        end
    endfunction

    // Local parameter for output width
    localparam CLOG2_WIDTH = clog2(WIDTH + 1);  // Plus one to handle all possible counts properly

    integer i;
    integer cnt;  // Declare variable without initialization

    always @* begin
        cnt = 0;  // Initialize cnt at the beginning of the block

        for (i = 0; i < WIDTH; i = i + 1) begin
            if (py[i] === 1'bx) begin
                cnt = cnt + 1;
            end
        end
        pa = cnt;  // Assign the count to the output pa
    end

endmodule
