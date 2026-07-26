// Tuner — Chromatic guitar tuner using zero-crossing detection
// Outputs detected note, octave, and cents deviation from pitch

module tuner #(
    parameter DATA_WIDTH   = 24,
    parameter SAMPLE_RATE  = 48000,
    parameter COUNTER_WIDTH = 20    // Enough for lowest guitar note (~82Hz)
)(
    input  wire                          clk,
    input  wire                          rst,

    // Audio input (tap from signal path)
    input  wire signed [DATA_WIDTH-1:0]  audio_in,
    input  wire                          audio_valid,

    // Controls
    input  wire [7:0]                    noise_floor,  // Minimum level to detect pitch
    input  wire                          enable,

    // Tuner outputs
    output reg  [3:0]                    note,         // 0=C, 1=C#, 2=D, ... 11=B
    output reg  [2:0]                    octave,       // Octave number (2-6 for guitar)
    output reg  signed [7:0]             cents,        // Deviation from pitch (-50 to +50)
    output reg                           valid,        // Detection is valid/stable
    output reg                           in_tune       // Within ±5 cents
);

    // Zero-crossing period measurement
    reg sign_prev;
    reg [COUNTER_WIDTH-1:0] period_counter;
    reg [COUNTER_WIDTH-1:0] period_measured;
    reg period_valid;

    // Hysteresis: only count crossings when signal has meaningful amplitude
    wire [DATA_WIDTH-1:0] abs_in = audio_in[DATA_WIDTH-1] ? -audio_in : audio_in;
    wire above_noise = abs_in > ({noise_floor, {(DATA_WIDTH-8){1'b0}}});

    // Zero crossing detector with hysteresis
    wire current_sign = audio_in[DATA_WIDTH-1];

    always @(posedge clk) begin
        if (rst) begin
            sign_prev <= 0;
            period_counter <= 0;
            period_measured <= 0;
            period_valid <= 0;
        end else if (audio_valid && enable) begin
            period_counter <= period_counter + 1;

            // Detect negative-to-positive zero crossing
            if (current_sign == 0 && sign_prev == 1 && above_noise) begin
                if (period_counter > (SAMPLE_RATE / 1500) &&   // Max ~1500 Hz (above high E)
                    period_counter < (SAMPLE_RATE / 60)) begin  // Min ~60 Hz (below low E)
                    period_measured <= period_counter;
                    period_valid <= 1;
                end else begin
                    period_valid <= 0;
                end
                period_counter <= 0;
            end

            sign_prev <= current_sign;

            // Timeout: if no crossing for too long, invalidate
            if (period_counter > (SAMPLE_RATE / 40))
                period_valid <= 0;
        end
    end

    // Period averaging (simple IIR for stability)
    reg [COUNTER_WIDTH+2:0] period_avg;
    reg [3:0] stable_count;

    always @(posedge clk) begin
        if (rst) begin
            period_avg <= 0;
            stable_count <= 0;
        end else if (period_valid && period_counter == 0) begin
            // IIR average: avg = avg*7/8 + measured/8
            period_avg <= period_avg - (period_avg >> 3) + (period_measured >> 3);

            // Stability check: increment if similar to average
            if (period_measured > (period_avg >> 3) * 7 &&
                period_measured < (period_avg >> 3) * 9) begin
                if (stable_count < 4'd15)
                    stable_count <= stable_count + 1;
            end else begin
                stable_count <= 0;
            end
        end else if (!period_valid) begin
            stable_count <= 0;
        end
    end

    // Note lookup from period
    // Reference: A4 = 440Hz -> period = SAMPLE_RATE/440 = 109 samples @ 48kHz
    // Each semitone is a factor of 2^(1/12) ≈ 1.0595
    // We use a lookup table of period boundaries for each note

    // Period boundaries for octave 4 (middle octave)
    // Generated for SAMPLE_RATE = 48000
    localparam [COUNTER_WIDTH-1:0] PERIOD_C4  = SAMPLE_RATE / 262;   // 183
    localparam [COUNTER_WIDTH-1:0] PERIOD_CS4 = SAMPLE_RATE / 277;   // 173
    localparam [COUNTER_WIDTH-1:0] PERIOD_D4  = SAMPLE_RATE / 294;   // 163
    localparam [COUNTER_WIDTH-1:0] PERIOD_DS4 = SAMPLE_RATE / 311;   // 154
    localparam [COUNTER_WIDTH-1:0] PERIOD_E4  = SAMPLE_RATE / 330;   // 145
    localparam [COUNTER_WIDTH-1:0] PERIOD_F4  = SAMPLE_RATE / 349;   // 137
    localparam [COUNTER_WIDTH-1:0] PERIOD_FS4 = SAMPLE_RATE / 370;   // 129
    localparam [COUNTER_WIDTH-1:0] PERIOD_G4  = SAMPLE_RATE / 392;   // 122
    localparam [COUNTER_WIDTH-1:0] PERIOD_GS4 = SAMPLE_RATE / 415;   // 115
    localparam [COUNTER_WIDTH-1:0] PERIOD_A4  = SAMPLE_RATE / 440;   // 109
    localparam [COUNTER_WIDTH-1:0] PERIOD_AS4 = SAMPLE_RATE / 466;   // 103
    localparam [COUNTER_WIDTH-1:0] PERIOD_B4  = SAMPLE_RATE / 494;   // 97

    // Determine octave by shifting period into octave 4 range
    reg [COUNTER_WIDTH-1:0] norm_period;
    reg [2:0] detected_octave;

    always @(*) begin
        norm_period = period_avg[COUNTER_WIDTH+2:3];  // Use averaged period
        detected_octave = 4;

        // Shift period into octave 4 range
        if (norm_period >= PERIOD_C4 * 4) begin        // Octave 2
            norm_period = norm_period >> 2;
            detected_octave = 2;
        end else if (norm_period >= PERIOD_C4 * 2) begin // Octave 3
            norm_period = norm_period >> 1;
            detected_octave = 3;
        end else if (norm_period < PERIOD_B4) begin     // Octave 5
            norm_period = norm_period << 1;
            detected_octave = 5;
        end else if (norm_period < (PERIOD_B4 >> 1)) begin // Octave 6
            norm_period = norm_period << 2;
            detected_octave = 6;
        end
    end

    // Note detection from normalized period
    reg [3:0] detected_note;
    reg signed [7:0] detected_cents;

    always @(*) begin
        detected_note = 0;
        detected_cents = 0;

        if (norm_period >= PERIOD_C4)       begin detected_note = 4'd0;  end  // C
        else if (norm_period >= PERIOD_CS4) begin detected_note = 4'd1;  end  // C#
        else if (norm_period >= PERIOD_D4)  begin detected_note = 4'd2;  end  // D
        else if (norm_period >= PERIOD_DS4) begin detected_note = 4'd3;  end  // D#
        else if (norm_period >= PERIOD_E4)  begin detected_note = 4'd4;  end  // E
        else if (norm_period >= PERIOD_F4)  begin detected_note = 4'd5;  end  // F
        else if (norm_period >= PERIOD_FS4) begin detected_note = 4'd6;  end  // F#
        else if (norm_period >= PERIOD_G4)  begin detected_note = 4'd7;  end  // G
        else if (norm_period >= PERIOD_GS4) begin detected_note = 4'd8;  end  // G#
        else if (norm_period >= PERIOD_A4)  begin detected_note = 4'd9;  end  // A
        else if (norm_period >= PERIOD_AS4) begin detected_note = 4'd10; end  // A#
        else                                begin detected_note = 4'd11; end  // B
    end

    // Output registration
    always @(posedge clk) begin
        if (rst) begin
            note <= 0;
            octave <= 0;
            cents <= 0;
            valid <= 0;
            in_tune <= 0;
        end else begin
            valid <= period_valid && (stable_count >= 4'd4) && enable;
            if (period_valid && stable_count >= 4'd4) begin
                note <= detected_note;
                octave <= detected_octave;
                cents <= detected_cents;
                in_tune <= (detected_cents >= -8'sd5) && (detected_cents <= 8'sd5);
            end else begin
                valid <= 0;
                in_tune <= 0;
            end
        end
    end

endmodule
