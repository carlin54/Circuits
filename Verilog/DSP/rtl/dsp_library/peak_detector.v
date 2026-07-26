// Peak Detector — finds the maximum value and its index in a stream
// Typically used to find peak bin in FFT magnitude spectrum

module peak_detector #(
    parameter DATA_WIDTH  = 24,
    parameter NUM_BINS    = 512,
    parameter INDEX_WIDTH = 9,   // $clog2(NUM_BINS)
    parameter STREAMING   = 1    // 1 = process one bin per clock
)(
    input  wire                          clk,
    input  wire                          rst,

    // Input stream (magnitude values, one per clock)
    input  wire [DATA_WIDTH-1:0]         data_in,
    input  wire                          valid_in,
    input  wire                          last_in,   // End of frame

    // Output (asserted for one clock when frame is complete)
    output reg  [DATA_WIDTH-1:0]         peak_mag,
    output reg  [INDEX_WIDTH-1:0]        peak_index,
    output reg                           done
);

    reg [DATA_WIDTH-1:0]  current_max;
    reg [INDEX_WIDTH-1:0] current_idx;
    reg [INDEX_WIDTH-1:0] bin_counter;

    always @(posedge clk) begin
        if (rst) begin
            current_max <= 0;
            current_idx <= 0;
            bin_counter <= 0;
            peak_mag <= 0;
            peak_index <= 0;
            done <= 0;
        end else begin
            done <= 0;

            if (valid_in) begin
                if (bin_counter == 0) begin
                    // First bin of new frame: reset tracking
                    current_max <= data_in;
                    current_idx <= 0;
                    bin_counter <= 1;
                end else begin
                    // Compare and update
                    if (data_in > current_max) begin
                        current_max <= data_in;
                        current_idx <= bin_counter;
                    end
                    bin_counter <= bin_counter + 1;
                end

                // End of frame
                if (last_in || bin_counter == NUM_BINS - 1) begin
                    // Output the peak
                    if (data_in > current_max) begin
                        peak_mag <= data_in;
                        peak_index <= bin_counter;
                    end else begin
                        peak_mag <= current_max;
                        peak_index <= current_idx;
                    end
                    done <= 1;
                    bin_counter <= 0;
                end
            end
        end
    end

endmodule
