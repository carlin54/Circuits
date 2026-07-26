// Guitar Amp Top — System integration with I2S, SPI control, effects chain
// Connects I2S ADC -> amp_channel -> I2S DAC with SPI parameter control

module guitar_amp_top #(
    parameter DATA_WIDTH      = 24,
    parameter SAMPLE_RATE     = 48000,
    parameter SYSTEM_CLK_HZ   = 100_000_000,
    parameter NUM_CHANNELS    = 1,
    parameter OVERSAMPLE_GAIN = 4,
    parameter MAX_DELAY_SEC   = 2,
    parameter MAX_COMB_DELAY  = 2048,
    parameter NUM_COMBS       = 4,
    parameter NUM_ALLPASS     = 2,
    parameter CAB_IR_LENGTH   = 512,
    parameter NUM_CAB_SLOTS   = 4,
    parameter EQ_BANDS        = 4,
    parameter NUM_PRESETS     = 8,
    parameter BAUD_RATE       = 115200
)(
    input  wire        clk,
    input  wire        rst,

    // I2S ADC interface
    input  wire        i2s_bclk_in,
    input  wire        i2s_lrclk_in,
    input  wire        i2s_sdata_in,

    // I2S DAC interface
    output wire        i2s_mclk_out,
    output wire        i2s_bclk_out,
    output wire        i2s_lrclk_out,
    output wire        i2s_sdata_out,

    // SPI slave interface
    input  wire        spi_clk,
    input  wire        spi_mosi,
    output wire        spi_miso,
    input  wire        spi_cs_n,

    // UART interface
    input  wire        uart_rxd,
    output wire        uart_txd,

    // GPIO
    input  wire [3:0]  footswitch,
    output wire [7:0]  led
);

    localparam MAX_DELAY_SAMPLES = MAX_DELAY_SEC * SAMPLE_RATE;
    localparam NUM_REGS = 128;

    // ==================== Register File ====================
    reg [7:0] regs [0:NUM_REGS-1];

    wire [7:0] spi_reg_addr;
    wire [7:0] spi_reg_wdata;
    wire       spi_reg_we;
    wire [7:0] spi_reg_rdata;

    assign spi_reg_rdata = regs[spi_reg_addr[6:0]];

    always @(posedge clk) begin
        if (rst) begin
            integer i;
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= 8'd0;
            // Defaults for unity passthrough
            regs[8'h07] <= 8'd128;  // Comp makeup = unity
            regs[8'h0A] <= 8'd128;  // Gain level = unity
            regs[8'h40] <= 8'd200;  // Master vol
            regs[8'h42] <= 8'd240;  // Limiter threshold (near 0dBFS)
            regs[8'h43] <= 8'd128;  // Limiter release
        end else begin
            if (spi_reg_we)
                regs[spi_reg_addr[6:0]] <= spi_reg_wdata;
        end
    end

    // ==================== SPI Slave ====================
    spi_slave #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(8),
        .NUM_REGS(NUM_REGS)
    ) u_spi (
        .clk(clk), .rst(rst),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .reg_addr(spi_reg_addr),
        .reg_wdata(spi_reg_wdata),
        .reg_we(spi_reg_we),
        .reg_rdata(spi_reg_rdata)
    );

    // ==================== UART ====================
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;

    uart_interface #(
        .CLK_FREQ(SYSTEM_CLK_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_uart (
        .clk(clk), .rst(rst),
        .s_axis_tdata(8'd0),
        .s_axis_tvalid(1'b0),
        .s_axis_tready(),
        .m_axis_tdata(uart_rx_data),
        .m_axis_tvalid(uart_rx_valid),
        .m_axis_tready(1'b1),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .tx_busy(),
        .rx_frame_error(),
        .rx_parity_error()
    );

    // ==================== I2S Receiver ====================
    wire signed [DATA_WIDTH-1:0] adc_data;
    wire                         adc_valid;
    wire                         adc_ready;
    wire                         adc_last;
    wire                         adc_channel;

    i2s_receiver #(
        .DATA_WIDTH(DATA_WIDTH),
        .JUSTIFICATION("I2S")
    ) u_i2s_rx (
        .clk(clk), .rst(rst),
        .m_axis_tdata(adc_data),
        .m_axis_tvalid(adc_valid),
        .m_axis_tready(adc_ready),
        .m_axis_tlast(adc_last),
        .m_axis_channel(adc_channel),
        .bclk(i2s_bclk_in),
        .lrclk(i2s_lrclk_in),
        .sdata(i2s_sdata_in)
    );

    // ==================== Amp Channel ====================
    wire signed [DATA_WIDTH-1:0] amp_out;
    wire                         amp_valid;
    wire                         amp_last;
    wire                         amp_ready;

    // Multi-byte registers
    wire [15:0] delay_time_w = {regs[8'h28], regs[8'h29]};
    wire [15:0] fx_bypass_w  = {regs[8'h45], regs[8'h44]};

    // Tuner outputs
    wire [3:0]  tuner_note_w;
    wire [2:0]  tuner_octave_w;
    wire signed [7:0] tuner_cents_w;
    wire        tuner_valid_w;
    wire        tuner_in_tune_w;

    amp_channel #(
        .DATA_WIDTH(DATA_WIDTH),
        .OVERSAMPLE(OVERSAMPLE_GAIN),
        .MAX_DELAY(MAX_DELAY_SAMPLES),
        .MAX_COMB_DELAY(MAX_COMB_DELAY),
        .NUM_COMBS(NUM_COMBS),
        .NUM_ALLPASS(NUM_ALLPASS),
        .CAB_IR_LENGTH(CAB_IR_LENGTH),
        .NUM_CAB_SLOTS(NUM_CAB_SLOTS),
        .EQ_BANDS(EQ_BANDS),
        .SAMPLE_RATE(SAMPLE_RATE)
    ) u_amp_channel (
        .clk(clk), .rst(rst),

        // Audio I/O
        .s_axis_tdata(adc_data),
        .s_axis_tvalid(adc_valid && !adc_channel),
        .s_axis_tready(adc_ready),
        .s_axis_tlast(adc_last),
        .m_axis_tdata(amp_out),
        .m_axis_tvalid(amp_valid),
        .m_axis_tready(amp_ready),
        .m_axis_tlast(amp_last),

        // Noise gate
        .gate_open_thresh(regs[8'h01]),
        .gate_close_thresh(regs[8'h01] - 8'd10),
        .gate_hold_time({8'd0, regs[8'h02]}),

        // Wah
        .wah_pedal(regs[8'h03]),
        .wah_resonance(regs[8'h04]),
        .wah_range_lo(regs[8'h05]),
        .wah_range_hi(regs[8'h06]),

        // Compressor
        .comp_threshold(regs[8'h08]),
        .comp_ratio(regs[8'h09]),
        .comp_attack({8'd0, regs[8'h0A]}),
        .comp_release({8'd0, regs[8'h0B]}),
        .comp_makeup(regs[8'h0C]),

        // Gain stage
        .drive(regs[8'h10]),
        .gain_level(regs[8'h11]),
        .clip_type(regs[8'h12][2:0]),

        // Tone stack
        .bass(regs[8'h14]),
        .mid(regs[8'h15]),
        .treble(regs[8'h16]),
        .presence(regs[8'h17]),
        .resonance(regs[8'h18]),

        // Parametric EQ
        .eq_freq({regs[8'h1C], regs[8'h1B], regs[8'h1A], regs[8'h19]}),
        .eq_gain({regs[8'h20], regs[8'h1F], regs[8'h1E], regs[8'h1D]}),
        .eq_q({regs[8'h24], regs[8'h23], regs[8'h22], regs[8'h21]}),
        .eq_coeff_we(1'b0),
        .eq_coeff_band(0),
        .eq_coeff_addr(0),
        .eq_coeff_data(0),

        // Chorus
        .chorus_rate(regs[8'h25]),
        .chorus_depth(regs[8'h26]),
        .chorus_mix(regs[8'h27]),

        // Flanger
        .flanger_rate(regs[8'h2A]),
        .flanger_depth(regs[8'h2B]),
        .flanger_fb($signed(regs[8'h2C])),
        .flanger_mix(regs[8'h2D]),

        // Pitch shift
        .pitch_shift_amt($signed(regs[8'h2E])),
        .pitch_shift_mix(regs[8'h2F]),

        // Tremolo
        .trem_rate(regs[8'h30]),
        .trem_depth(regs[8'h31]),
        .trem_shape(regs[8'h32][1:0]),

        // Delay
        .delay_time(delay_time_w),
        .delay_feedback(regs[8'h34]),
        .delay_mix(regs[8'h35]),

        // Reverb
        .reverb_decay(regs[8'h38]),
        .reverb_damping(regs[8'h39]),
        .reverb_mix(regs[8'h3A]),

        // Cabinet
        .cab_select(regs[8'h3C][$clog2(NUM_CAB_SLOTS)-1:0]),
        .cab_bypass(regs[8'h3D][0]),

        // Limiter
        .limiter_threshold(regs[8'h42]),
        .limiter_release(regs[8'h43]),

        // Master
        .master_vol(regs[8'h40]),
        .fx_bypass(fx_bypass_w),
        .mod_select(regs[8'h46][1:0]),

        // Cabinet IR loading
        .ir_we(1'b0),
        .ir_slot(0),
        .ir_addr(0),
        .ir_wdata(0),

        // Tuner
        .tuner_enable(regs[8'h48][0]),
        .tuner_noise_floor(regs[8'h49]),
        .tuner_note(tuner_note_w),
        .tuner_octave(tuner_octave_w),
        .tuner_cents(tuner_cents_w),
        .tuner_valid(tuner_valid_w),
        .tuner_in_tune(tuner_in_tune_w)
    );

    // ==================== I2S Transmitter ====================
    i2s_transmitter #(
        .DATA_WIDTH(DATA_WIDTH),
        .JUSTIFICATION("I2S"),
        .MCLK_DIVIDE(8),
        .LRCLK_DIVIDE(64)
    ) u_i2s_tx (
        .clk(clk), .rst(rst),
        .s_axis_tdata(amp_out),
        .s_axis_tvalid(amp_valid),
        .s_axis_tready(amp_ready),
        .s_axis_tlast(amp_last),
        .mclk(i2s_mclk_out),
        .bclk(i2s_bclk_out),
        .lrclk(i2s_lrclk_out),
        .sdata(i2s_sdata_out)
    );

    // ==================== Footswitch Logic ====================
    reg [3:0] fs_sync [0:2];
    reg [3:0] fs_prev;
    wire [3:0] fs_press = fs_sync[2] & ~fs_prev;

    always @(posedge clk) begin
        if (rst) begin
            fs_sync[0] <= 0;
            fs_sync[1] <= 0;
            fs_sync[2] <= 0;
            fs_prev <= 0;
        end else begin
            fs_sync[0] <= footswitch;
            fs_sync[1] <= fs_sync[0];
            fs_sync[2] <= fs_sync[1];
            fs_prev <= fs_sync[2];
        end
    end

    // ==================== LED Indicators ====================
    assign led[0] = amp_valid;              // Signal present
    assign led[1] = tuner_valid_w;          // Tuner active
    assign led[2] = tuner_in_tune_w;        // In tune indicator
    assign led[3] = |regs[8'h10];           // Drive active
    assign led[4] = !fx_bypass_w[6];        // Modulation active
    assign led[5] = !fx_bypass_w[8];        // Delay active
    assign led[6] = !fx_bypass_w[9];        // Reverb active
    assign led[7] = footswitch[0];          // Footswitch state

endmodule
