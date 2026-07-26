// Amp Channel — Configurable effects chain
// Signal path: noise_gate -> wah -> compressor -> gain_stage -> tone_stack -> eq_parametric
//   -> [chorus/flanger] -> tremolo -> delay -> reverb -> cab_sim -> limiter -> master volume
// Also: tuner (tapped from input), pitch_shift (in modulation slot)

module amp_channel #(
    parameter DATA_WIDTH      = 24,
    parameter COEFF_WIDTH     = 18,
    parameter INTERNAL_WIDTH  = 40,
    parameter OVERSAMPLE      = 4,
    parameter MAX_DELAY       = 96000,
    parameter MAX_COMB_DELAY  = 2048,
    parameter NUM_COMBS       = 4,
    parameter NUM_ALLPASS     = 2,
    parameter CAB_IR_LENGTH   = 512,
    parameter NUM_CAB_SLOTS   = 4,
    parameter EQ_BANDS        = 4,
    parameter SAMPLE_RATE     = 48000
)(
    input  wire                          clk,
    input  wire                          rst,

    // AXI-Stream input
    input  wire signed [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                          s_axis_tvalid,
    output wire                          s_axis_tready,
    input  wire                          s_axis_tlast,

    // AXI-Stream output
    output wire signed [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                          m_axis_tvalid,
    input  wire                          m_axis_tready,
    output wire                          m_axis_tlast,

    // Noise gate controls
    input  wire [7:0]                    gate_open_thresh,
    input  wire [7:0]                    gate_close_thresh,
    input  wire [15:0]                   gate_hold_time,

    // Wah controls
    input  wire [7:0]                    wah_pedal,
    input  wire [7:0]                    wah_resonance,
    input  wire [7:0]                    wah_range_lo,
    input  wire [7:0]                    wah_range_hi,

    // Compressor controls
    input  wire [7:0]                    comp_threshold,
    input  wire [7:0]                    comp_ratio,
    input  wire [15:0]                   comp_attack,
    input  wire [15:0]                   comp_release,
    input  wire [7:0]                    comp_makeup,

    // Gain stage controls
    input  wire [7:0]                    drive,
    input  wire [7:0]                    gain_level,
    input  wire [2:0]                    clip_type,

    // Tone stack controls
    input  wire [7:0]                    bass,
    input  wire [7:0]                    mid,
    input  wire [7:0]                    treble,
    input  wire [7:0]                    presence,
    input  wire [7:0]                    resonance,

    // Parametric EQ controls
    input  wire [8*EQ_BANDS-1:0]         eq_freq,
    input  wire [8*EQ_BANDS-1:0]         eq_gain,
    input  wire [8*EQ_BANDS-1:0]         eq_q,
    input  wire                          eq_coeff_we,
    input  wire [$clog2(EQ_BANDS)-1:0]   eq_coeff_band,
    input  wire [2:0]                    eq_coeff_addr,
    input  wire signed [COEFF_WIDTH-1:0] eq_coeff_data,

    // Chorus controls
    input  wire [7:0]                    chorus_rate,
    input  wire [7:0]                    chorus_depth,
    input  wire [7:0]                    chorus_mix,

    // Flanger controls
    input  wire [7:0]                    flanger_rate,
    input  wire [7:0]                    flanger_depth,
    input  wire signed [7:0]             flanger_fb,
    input  wire [7:0]                    flanger_mix,

    // Pitch shift controls
    input  wire signed [7:0]             pitch_shift_amt,
    input  wire [7:0]                    pitch_shift_mix,

    // Tremolo controls
    input  wire [7:0]                    trem_rate,
    input  wire [7:0]                    trem_depth,
    input  wire [1:0]                    trem_shape,

    // Delay controls
    input  wire [15:0]                   delay_time,
    input  wire [7:0]                    delay_feedback,
    input  wire [7:0]                    delay_mix,

    // Reverb controls
    input  wire [7:0]                    reverb_decay,
    input  wire [7:0]                    reverb_damping,
    input  wire [7:0]                    reverb_mix,

    // Cabinet controls
    input  wire [$clog2(NUM_CAB_SLOTS)-1:0] cab_select,
    input  wire                          cab_bypass,

    // Limiter controls
    input  wire [7:0]                    limiter_threshold,
    input  wire [7:0]                    limiter_release,

    // Master volume
    input  wire [7:0]                    master_vol,

    // Per-effect bypass (expanded to 16 bits)
    input  wire [15:0]                   fx_bypass,

    // Modulation mode select
    input  wire [1:0]                    mod_select,   // 0=chorus, 1=flanger, 2=pitch_shift, 3=off

    // Cabinet IR loading
    input  wire                          ir_we,
    input  wire [$clog2(NUM_CAB_SLOTS)-1:0] ir_slot,
    input  wire [$clog2(CAB_IR_LENGTH)-1:0] ir_addr,
    input  wire signed [15:0]            ir_wdata,

    // Tuner outputs (active even when muted)
    output wire [3:0]                    tuner_note,
    output wire [2:0]                    tuner_octave,
    output wire signed [7:0]             tuner_cents,
    output wire                          tuner_valid,
    output wire                          tuner_in_tune,

    // Tuner controls
    input  wire                          tuner_enable,
    input  wire [7:0]                    tuner_noise_floor
);

    // Bypass bits
    wire bypass_gate    = fx_bypass[0];
    wire bypass_wah     = fx_bypass[1];
    wire bypass_comp    = fx_bypass[2];
    wire bypass_gain    = fx_bypass[3];
    wire bypass_tone    = fx_bypass[4];
    wire bypass_eq      = fx_bypass[5];
    wire bypass_mod     = fx_bypass[6];  // chorus/flanger/pitch
    wire bypass_trem    = fx_bypass[7];
    wire bypass_delay   = fx_bypass[8];
    wire bypass_reverb  = fx_bypass[9];
    wire bypass_cab     = fx_bypass[10] | cab_bypass;
    wire bypass_limiter = fx_bypass[11];

    // Inter-stage wires
    wire signed [DATA_WIDTH-1:0] gate_out, wah_out, comp_out, gain_out, tone_out, eq_out;
    wire signed [DATA_WIDTH-1:0] mod_out, trem_out, delay_out, reverb_out, cab_out, lim_out;
    wire gate_valid, wah_valid, comp_valid, gain_valid, tone_valid, eq_valid;
    wire mod_valid, trem_valid, delay_valid, reverb_valid, cab_valid, lim_valid;
    wire gate_ready, wah_ready, comp_ready, gain_ready, tone_ready, eq_ready;
    wire mod_ready, trem_ready, delay_ready, reverb_ready, cab_ready, lim_ready;
    wire gate_last, wah_last, comp_last, gain_last, tone_last, eq_last;
    wire mod_last, trem_last, delay_last, reverb_last, cab_last, lim_last;

    // === Tuner (tapped from input, does not affect signal path) ===
    tuner #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLE_RATE(SAMPLE_RATE)
    ) u_tuner (
        .clk(clk), .rst(rst),
        .audio_in(s_axis_tdata),
        .audio_valid(s_axis_tvalid),
        .noise_floor(tuner_noise_floor),
        .enable(tuner_enable),
        .note(tuner_note),
        .octave(tuner_octave),
        .cents(tuner_cents),
        .valid(tuner_valid),
        .in_tune(tuner_in_tune)
    );

    // === Stage 1: Noise Gate ===
    wire signed [DATA_WIDTH-1:0] s1_data  = bypass_gate ? s_axis_tdata : gate_out;
    wire                         s1_valid = bypass_gate ? s_axis_tvalid : gate_valid;
    wire                         s1_last  = bypass_gate ? s_axis_tlast : gate_last;
    assign s_axis_tready = bypass_gate ? wah_ready : gate_ready;

    noise_gate #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_noise_gate (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(gate_ready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(gate_out),
        .m_axis_tvalid(gate_valid),
        .m_axis_tready(wah_ready),
        .m_axis_tlast(gate_last),
        .open_threshold(gate_open_thresh),
        .close_threshold(gate_close_thresh),
        .hold_time(gate_hold_time)
    );

    // === Stage 2: Wah ===
    wire signed [DATA_WIDTH-1:0] s2_data  = bypass_wah ? s1_data : wah_out;
    wire                         s2_valid = bypass_wah ? s1_valid : wah_valid;
    wire                         s2_last  = bypass_wah ? s1_last : wah_last;

    wah #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH)
    ) u_wah (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s1_data),
        .s_axis_tvalid(s1_valid),
        .s_axis_tready(wah_ready),
        .s_axis_tlast(s1_last),
        .m_axis_tdata(wah_out),
        .m_axis_tvalid(wah_valid),
        .m_axis_tready(comp_ready),
        .m_axis_tlast(wah_last),
        .pedal_pos(wah_pedal),
        .resonance(wah_resonance),
        .range_lo(wah_range_lo),
        .range_hi(wah_range_hi),
        .sensitivity(8'd0)
    );

    // === Stage 3: Compressor ===
    wire signed [DATA_WIDTH-1:0] s3_data  = bypass_comp ? s2_data : comp_out;
    wire                         s3_valid = bypass_comp ? s2_valid : comp_valid;
    wire                         s3_last  = bypass_comp ? s2_last : comp_last;

    compressor #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_compressor (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s2_data),
        .s_axis_tvalid(s2_valid),
        .s_axis_tready(comp_ready),
        .s_axis_tlast(s2_last),
        .m_axis_tdata(comp_out),
        .m_axis_tvalid(comp_valid),
        .m_axis_tready(gain_ready),
        .m_axis_tlast(comp_last),
        .threshold(comp_threshold),
        .ratio(comp_ratio),
        .attack(comp_attack),
        .release_coeff(comp_release),
        .makeup(comp_makeup)
    );

    // === Stage 4: Gain Stage ===
    wire signed [DATA_WIDTH-1:0] s4_data  = bypass_gain ? s3_data : gain_out;
    wire                         s4_valid = bypass_gain ? s3_valid : gain_valid;
    wire                         s4_last  = bypass_gain ? s3_last : gain_last;

    gain_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .OVERSAMPLE(OVERSAMPLE)
    ) u_gain_stage (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s3_data),
        .s_axis_tvalid(s3_valid),
        .s_axis_tready(gain_ready),
        .s_axis_tlast(s3_last),
        .m_axis_tdata(gain_out),
        .m_axis_tvalid(gain_valid),
        .m_axis_tready(tone_ready),
        .m_axis_tlast(gain_last),
        .drive(drive),
        .level(gain_level),
        .curve_sel(clip_type)
    );

    // === Stage 5: Tone Stack ===
    wire signed [DATA_WIDTH-1:0] s5_data  = bypass_tone ? s4_data : tone_out;
    wire                         s5_valid = bypass_tone ? s4_valid : tone_valid;
    wire                         s5_last  = bypass_tone ? s4_last : tone_last;

    tone_stack #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH)
    ) u_tone_stack (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s4_data),
        .s_axis_tvalid(s4_valid),
        .s_axis_tready(tone_ready),
        .s_axis_tlast(s4_last),
        .m_axis_tdata(tone_out),
        .m_axis_tvalid(tone_valid),
        .m_axis_tready(eq_ready),
        .m_axis_tlast(tone_last),
        .bass(bass),
        .mid(mid),
        .treble(treble),
        .presence(presence),
        .resonance(resonance)
    );

    // === Stage 6: Parametric EQ ===
    wire signed [DATA_WIDTH-1:0] s6_data  = bypass_eq ? s5_data : eq_out;
    wire                         s6_valid = bypass_eq ? s5_valid : eq_valid;
    wire                         s6_last  = bypass_eq ? s5_last : eq_last;

    eq_parametric #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .INTERNAL_WIDTH(INTERNAL_WIDTH),
        .NUM_BANDS(EQ_BANDS)
    ) u_eq (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s5_data),
        .s_axis_tvalid(s5_valid),
        .s_axis_tready(eq_ready),
        .s_axis_tlast(s5_last),
        .m_axis_tdata(eq_out),
        .m_axis_tvalid(eq_valid),
        .m_axis_tready(mod_ready),
        .m_axis_tlast(eq_last),
        .band_freq(eq_freq),
        .band_gain(eq_gain),
        .band_q(eq_q),
        .coeff_we(eq_coeff_we),
        .coeff_band(eq_coeff_band),
        .coeff_addr(eq_coeff_addr),
        .coeff_data(eq_coeff_data)
    );

    // === Stage 7: Modulation (Chorus / Flanger / Pitch Shift — selectable) ===
    wire signed [DATA_WIDTH-1:0] chorus_out_data, flanger_out_data, pitch_out_data;
    wire chorus_out_valid, flanger_out_valid, pitch_out_valid;
    wire chorus_out_last, flanger_out_last, pitch_out_last;
    wire chorus_ready_w, flanger_ready_w, pitch_ready_w;

    // Select active modulation effect
    reg signed [DATA_WIDTH-1:0] mod_selected_data;
    reg mod_selected_valid, mod_selected_last;

    always @(*) begin
        case (mod_select)
            2'd0: begin mod_selected_data = chorus_out_data;  mod_selected_valid = chorus_out_valid;  mod_selected_last = chorus_out_last;  end
            2'd1: begin mod_selected_data = flanger_out_data; mod_selected_valid = flanger_out_valid; mod_selected_last = flanger_out_last; end
            2'd2: begin mod_selected_data = pitch_out_data;   mod_selected_valid = pitch_out_valid;   mod_selected_last = pitch_out_last;   end
            default: begin mod_selected_data = s6_data;       mod_selected_valid = s6_valid;          mod_selected_last = s6_last;          end
        endcase
    end

    wire signed [DATA_WIDTH-1:0] s7_data  = bypass_mod ? s6_data : mod_selected_data;
    wire                         s7_valid = bypass_mod ? s6_valid : mod_selected_valid;
    wire                         s7_last  = bypass_mod ? s6_last : mod_selected_last;

    chorus #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_chorus (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s6_data),
        .s_axis_tvalid(s6_valid && mod_select == 2'd0),
        .s_axis_tready(chorus_ready_w),
        .s_axis_tlast(s6_last),
        .m_axis_tdata(chorus_out_data),
        .m_axis_tvalid(chorus_out_valid),
        .m_axis_tready(trem_ready),
        .m_axis_tlast(chorus_out_last),
        .rate(chorus_rate),
        .depth(chorus_depth),
        .mix(chorus_mix)
    );

    flanger #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_flanger (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s6_data),
        .s_axis_tvalid(s6_valid && mod_select == 2'd1),
        .s_axis_tready(flanger_ready_w),
        .s_axis_tlast(s6_last),
        .m_axis_tdata(flanger_out_data),
        .m_axis_tvalid(flanger_out_valid),
        .m_axis_tready(trem_ready),
        .m_axis_tlast(flanger_out_last),
        .rate(flanger_rate),
        .depth(flanger_depth),
        .feedback(flanger_fb),
        .mix(flanger_mix)
    );

    pitch_shift #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_pitch_shift (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s6_data),
        .s_axis_tvalid(s6_valid && mod_select == 2'd2),
        .s_axis_tready(pitch_ready_w),
        .s_axis_tlast(s6_last),
        .m_axis_tdata(pitch_out_data),
        .m_axis_tvalid(pitch_out_valid),
        .m_axis_tready(trem_ready),
        .m_axis_tlast(pitch_out_last),
        .shift(pitch_shift_amt),
        .mix(pitch_shift_mix),
        .grain_size_ctrl(8'd128)
    );

    assign mod_ready = (mod_select == 2'd0) ? chorus_ready_w :
                       (mod_select == 2'd1) ? flanger_ready_w :
                       (mod_select == 2'd2) ? pitch_ready_w : trem_ready;

    // === Stage 8: Tremolo ===
    wire signed [DATA_WIDTH-1:0] s8_data  = bypass_trem ? s7_data : trem_out;
    wire                         s8_valid = bypass_trem ? s7_valid : trem_valid;
    wire                         s8_last  = bypass_trem ? s7_last : trem_last;

    tremolo #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_tremolo (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s7_data),
        .s_axis_tvalid(s7_valid),
        .s_axis_tready(trem_ready),
        .s_axis_tlast(s7_last),
        .m_axis_tdata(trem_out),
        .m_axis_tvalid(trem_valid),
        .m_axis_tready(delay_ready),
        .m_axis_tlast(trem_last),
        .rate(trem_rate),
        .depth(trem_depth),
        .shape(trem_shape)
    );

    // === Stage 9: Delay ===
    wire signed [DATA_WIDTH-1:0] s9_data  = bypass_delay ? s8_data : delay_out;
    wire                         s9_valid = bypass_delay ? s8_valid : delay_valid;
    wire                         s9_last  = bypass_delay ? s8_last : delay_last;

    delay_line #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_DELAY_SAMPLES(MAX_DELAY)
    ) u_delay (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s8_data),
        .s_axis_tvalid(s8_valid),
        .s_axis_tready(delay_ready),
        .s_axis_tlast(s8_last),
        .m_axis_tdata(delay_out),
        .m_axis_tvalid(delay_valid),
        .m_axis_tready(reverb_ready),
        .m_axis_tlast(delay_last),
        .delay_time(delay_time),
        .feedback(delay_feedback),
        .mix(delay_mix)
    );

    // === Stage 10: Reverb ===
    wire signed [DATA_WIDTH-1:0] s10_data  = bypass_reverb ? s9_data : reverb_out;
    wire                         s10_valid = bypass_reverb ? s9_valid : reverb_valid;
    wire                         s10_last  = bypass_reverb ? s9_last : reverb_last;

    reverb #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAX_COMB_DELAY(MAX_COMB_DELAY),
        .NUM_COMBS(NUM_COMBS),
        .NUM_ALLPASS(NUM_ALLPASS)
    ) u_reverb (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s9_data),
        .s_axis_tvalid(s9_valid),
        .s_axis_tready(reverb_ready),
        .s_axis_tlast(s9_last),
        .m_axis_tdata(reverb_out),
        .m_axis_tvalid(reverb_valid),
        .m_axis_tready(cab_ready),
        .m_axis_tlast(reverb_last),
        .decay(reverb_decay),
        .damping_ctrl(reverb_damping),
        .mix(reverb_mix)
    );

    // === Stage 11: Cabinet Simulation ===
    wire signed [DATA_WIDTH-1:0] s11_data;
    wire                         s11_valid;
    wire                         s11_last;

    cab_sim #(
        .DATA_WIDTH(DATA_WIDTH),
        .IR_LENGTH(CAB_IR_LENGTH),
        .NUM_IR_SLOTS(NUM_CAB_SLOTS)
    ) u_cab_sim (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s10_data),
        .s_axis_tvalid(s10_valid),
        .s_axis_tready(cab_ready),
        .s_axis_tlast(s10_last),
        .m_axis_tdata(cab_out),
        .m_axis_tvalid(cab_valid),
        .m_axis_tready(lim_ready),
        .m_axis_tlast(cab_last),
        .ir_select(cab_select),
        .bypass(bypass_cab),
        .ir_we(ir_we),
        .ir_slot(ir_slot),
        .ir_addr(ir_addr),
        .ir_wdata(ir_wdata)
    );

    assign s11_data  = bypass_cab ? s10_data : cab_out;
    assign s11_valid = bypass_cab ? s10_valid : cab_valid;
    assign s11_last  = bypass_cab ? s10_last : cab_last;

    // === Stage 12: Limiter ===
    wire signed [DATA_WIDTH-1:0] s12_data  = bypass_limiter ? s11_data : lim_out;
    wire                         s12_valid = bypass_limiter ? s11_valid : lim_valid;
    wire                         s12_last  = bypass_limiter ? s11_last : lim_last;

    limiter #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_limiter (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s11_data),
        .s_axis_tvalid(s11_valid),
        .s_axis_tready(lim_ready),
        .s_axis_tlast(s11_last),
        .m_axis_tdata(lim_out),
        .m_axis_tvalid(lim_valid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(lim_last),
        .threshold(limiter_threshold),
        .release_ctrl(limiter_release)
    );

    // === Master Volume ===
    reg signed [DATA_WIDTH-1:0] master_out;
    reg master_valid_r;
    reg master_last_r;

    always @(posedge clk) begin
        if (rst) begin
            master_out <= 0;
            master_valid_r <= 0;
            master_last_r <= 0;
        end else begin
            if (master_valid_r && m_axis_tready)
                master_valid_r <= 0;

            if (s12_valid) begin
                reg signed [DATA_WIDTH+7:0] scaled;
                scaled = s12_data * $signed({1'b0, master_vol});
                master_out <= scaled >>> 8;
                master_valid_r <= 1;
                master_last_r <= s12_last;
            end
        end
    end

    assign m_axis_tdata  = master_out;
    assign m_axis_tvalid = master_valid_r;
    assign m_axis_tlast  = master_last_r;

endmodule
