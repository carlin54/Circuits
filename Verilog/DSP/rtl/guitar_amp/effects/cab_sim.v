// Cabinet Simulation — Long FIR convolution with impulse response
// Resource-shared: single multiplier, processes one tap per clock
// At 100MHz system clock and 48kHz sample rate, we have ~2083 clocks per sample

module cab_sim #(
    parameter DATA_WIDTH      = 24,
    parameter COEFF_WIDTH     = 16,
    parameter IR_LENGTH       = 512,
    parameter NUM_IR_SLOTS    = 4,
    parameter IR_MEM_TYPE     = "BLOCK_RAM",
    parameter CROSSFADE       = 1,
    parameter CROSSFADE_LEN   = 64,
    parameter INTERNAL_WIDTH  = 48,
    parameter IR_INIT_FILE    = ""
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output reg  signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,
    output reg                           m_axis_tlast,

    // Cabinet selection
    input  wire [$clog2(NUM_IR_SLOTS)-1:0] ir_select,
    input  wire                          bypass,

    // IR coefficient loading interface
    input  wire                          ir_we,
    input  wire [$clog2(NUM_IR_SLOTS)-1:0] ir_slot,
    input  wire [$clog2(IR_LENGTH)-1:0]  ir_addr,
    input  wire signed [COEFF_WIDTH-1:0] ir_wdata
);

    localparam ADDR_WIDTH = $clog2(IR_LENGTH);
    localparam SLOT_ADDR_WIDTH = $clog2(NUM_IR_SLOTS) + ADDR_WIDTH;

    // IR coefficient memory
    reg signed [COEFF_WIDTH-1:0] ir_mem [0:(NUM_IR_SLOTS * IR_LENGTH)-1];

    // Sample delay line (circular buffer)
    reg signed [DATA_WIDTH-1:0] sample_buf [0:IR_LENGTH-1];
    reg [ADDR_WIDTH-1:0] buf_wr_ptr;

    // MAC engine state
    reg [1:0] mac_state;
    localparam MAC_IDLE    = 2'd0;
    localparam MAC_RUNNING = 2'd1;
    localparam MAC_DONE    = 2'd2;

    reg [ADDR_WIDTH-1:0] tap_counter;
    reg signed [INTERNAL_WIDTH-1:0] accumulator;
    reg signed [DATA_WIDTH-1:0] input_sample;
    reg input_tlast;

    // Crossfade state
    reg [$clog2(NUM_IR_SLOTS)-1:0] active_ir;
    reg [$clog2(NUM_IR_SLOTS)-1:0] next_ir;
    reg crossfading;
    reg [$clog2(CROSSFADE_LEN):0] cf_counter;
    reg signed [INTERNAL_WIDTH-1:0] accum_old;
    reg signed [INTERNAL_WIDTH-1:0] accum_new;

    // IR memory address generation
    wire [SLOT_ADDR_WIDTH-1:0] ir_rd_addr = {active_ir, tap_counter};
    wire [SLOT_ADDR_WIDTH-1:0] ir_rd_addr_new = {next_ir, tap_counter};
    wire [SLOT_ADDR_WIDTH-1:0] ir_wr_full_addr = {ir_slot, ir_addr};

    // Read pointer for sample buffer (wraps around)
    wire [ADDR_WIDTH-1:0] buf_rd_ptr = buf_wr_ptr - tap_counter - 1;

    assign s_axis_tready = (mac_state == MAC_IDLE) && (m_axis_tready || !m_axis_tvalid);

    // IR memory write
    always @(posedge clk) begin
        if (ir_we)
            ir_mem[ir_wr_full_addr] <= ir_wdata;
    end

    // Initialize IR memory from file
    initial begin
        if (IR_INIT_FILE != "")
            $readmemh(IR_INIT_FILE, ir_mem);
    end

    always @(posedge clk) begin
        if (rst) begin
            mac_state <= MAC_IDLE;
            tap_counter <= 0;
            accumulator <= 0;
            buf_wr_ptr <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast <= 0;
            active_ir <= 0;
            next_ir <= 0;
            crossfading <= 0;
            cf_counter <= 0;
            accum_old <= 0;
            accum_new <= 0;
            input_sample <= 0;
            input_tlast <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;

            case (mac_state)
                MAC_IDLE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Store new sample in circular buffer
                        sample_buf[buf_wr_ptr] <= s_axis_tdata;
                        buf_wr_ptr <= buf_wr_ptr + 1;
                        input_sample <= s_axis_tdata;
                        input_tlast <= s_axis_tlast;

                        if (bypass) begin
                            m_axis_tdata <= s_axis_tdata;
                            m_axis_tvalid <= 1;
                            m_axis_tlast <= s_axis_tlast;
                        end else begin
                            // Start MAC computation
                            mac_state <= MAC_RUNNING;
                            tap_counter <= 0;
                            accumulator <= 0;

                            // Check for IR change
                            if (ir_select != active_ir && !crossfading && CROSSFADE) begin
                                crossfading <= 1;
                                next_ir <= ir_select;
                                cf_counter <= 0;
                                accum_new <= 0;
                            end else if (ir_select != active_ir && !CROSSFADE) begin
                                active_ir <= ir_select;
                            end
                        end
                    end
                end

                MAC_RUNNING: begin
                    // One multiply-accumulate per clock
                    reg signed [DATA_WIDTH-1:0] sample;
                    reg signed [COEFF_WIDTH-1:0] coeff;
                    sample = sample_buf[buf_rd_ptr];
                    coeff = ir_mem[ir_rd_addr];

                    accumulator <= accumulator + sample * coeff;

                    // Also compute new IR accumulator during crossfade
                    if (crossfading) begin
                        reg signed [COEFF_WIDTH-1:0] coeff_new;
                        coeff_new = ir_mem[ir_rd_addr_new];
                        accum_new <= accum_new + sample * coeff_new;
                    end

                    if (tap_counter == IR_LENGTH - 1) begin
                        mac_state <= MAC_DONE;
                    end else begin
                        tap_counter <= tap_counter + 1;
                    end
                end

                MAC_DONE: begin
                    // Output result (scale down by COEFF fractional bits)
                    reg signed [DATA_WIDTH-1:0] result;

                    if (crossfading) begin
                        // Crossfade between old and new IR
                        reg signed [INTERNAL_WIDTH-1:0] old_scaled, new_scaled;
                        reg [7:0] fade_gain;
                        fade_gain = (cf_counter * 255) / CROSSFADE_LEN;
                        old_scaled = (accumulator >>> (COEFF_WIDTH - 1)) * $signed({1'b0, (8'd255 - fade_gain)});
                        new_scaled = (accum_new >>> (COEFF_WIDTH - 1)) * $signed({1'b0, fade_gain});
                        result = (old_scaled + new_scaled) >>> 8;

                        if (cf_counter >= CROSSFADE_LEN - 1) begin
                            crossfading <= 0;
                            active_ir <= next_ir;
                        end else begin
                            cf_counter <= cf_counter + 1;
                        end
                    end else begin
                        result = accumulator >>> (COEFF_WIDTH - 1);
                    end

                    // Saturate output
                    if (result > $signed({1'b0, {(DATA_WIDTH-1){1'b1}}}))
                        m_axis_tdata <= {1'b0, {(DATA_WIDTH-1){1'b1}}};
                    else if (result < $signed({1'b1, {(DATA_WIDTH-1){1'b0}}}))
                        m_axis_tdata <= {1'b1, {(DATA_WIDTH-1){1'b0}}};
                    else
                        m_axis_tdata <= result;

                    m_axis_tvalid <= 1;
                    m_axis_tlast <= input_tlast;
                    mac_state <= MAC_IDLE;
                end

                default: mac_state <= MAC_IDLE;
            endcase
        end
    end

endmodule
