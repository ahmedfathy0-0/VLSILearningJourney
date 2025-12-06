`timescale 1ns/1ps
module verify_debouncer;

    // Parameters
    localparam CLK_PERIOD      = 10;
    localparam DEBOUNCE_CYCLES = 5;

    // Signals
    reg clk;
    reg reset;
    reg noisy_button;

    wire clean_pulse_tb;
    wire clean_pulse_synth;

    // Instantiate Behavioral Model
    debouncer_tb #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) tb_version (
        .clk(clk),
        .reset(reset),
        .noisy_button(noisy_button),
        .clean_pulse(clean_pulse_tb)
    );

    // Instantiate Synthesizable Hardware (Student's Version)
    debouncer #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
    ) synth_version (
        .clk(clk),
        .reset(reset),
        .noisy_button(noisy_button),
        .clean_pulse(clean_pulse_synth)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Stimulus
    initial begin
        $dumpfile("debouncer_waves.vcd");
        $dumpvars(0, verify_debouncer);
        
        // --- Initial State ---
        noisy_button <= 1; // Button is not pressed
        reset <= 1;
        #(CLK_PERIOD * 2);
        reset <= 0;
        #(CLK_PERIOD * 5);

        // --- SCENARIO 1: A clean, valid press ---
        $display("Test 1: Clean Press (should be accepted)");
        noisy_button <= 0; // Press the button
        #(CLK_PERIOD * (DEBOUNCE_CYCLES + 5));
        noisy_button <= 1; // Release the button
        #(CLK_PERIOD * 5);

        // --- SCENARIO 2: A short noise pulse ---
        $display("Test 2: Short Noise Pulse (should be rejected)");
        noisy_button <= 0;
        #(CLK_PERIOD * 1); // Shorter than DEBOUNCE_CYCLES
        noisy_button <= 1;
        #(CLK_PERIOD * 5);
        
        // --- SCENARIO 3: A longer, but still invalid noise pulse ---
        $display("Test 3: Almost-Valid Noise Pulse (should be rejected)");
        noisy_button <= 0;
        #(CLK_PERIOD * (DEBOUNCE_CYCLES - 1)); // One cycle too short
        noisy_button <= 1;
        #(CLK_PERIOD * 5);

        // --- SCENARIO 4: Debounce phase interrupted by reset ---
        $display("Test 4: Debounce Interrupted by Reset (should be rejected)");
        noisy_button <= 0;
        #(CLK_PERIOD * (DEBOUNCE_CYCLES - 2)); // Wait for 3 cycles
        reset <= 1; // Assert reset during the debounce wait
        #(CLK_PERIOD * 2);
        reset <= 0;
        noisy_button <= 1; // Release button after reset
        #(CLK_PERIOD * 5);
        
        // --- SCENARIO 5: Output pulse interrupted by reset ---
        $display("Test 5: Pulse Interrupted by Reset (pulse should be cut short)");
        noisy_button <= 0; // Start a valid press
        #(CLK_PERIOD * DEBOUNCE_CYCLES); // Wait for debounce to complete
        // The clean_pulse should go high on the next clock edge.
        // We will interrupt it half a cycle later.
        #((CLK_PERIOD+2)/2);
        reset <= 1; // Assert reset, immediately killing the pulse
        #(CLK_PERIOD * 2);
        reset <= 0;
        noisy_button <= 1;
        #(CLK_PERIOD * 5);

        $finish;
    end

endmodule

