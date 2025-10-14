// STUDENT TO COMPLETE THIS MODULE
// This module must be a synthesizable, synchronous hardware implementation
// of a button debouncer.

// =================================================================
// DELIVERABLE QUESTION:
// Explain why the FSM's ability to check the button state *during*
// the debounce delay is critical for rejecting noise.
//
// YOUR ANSWER:
// [Write your answer here]
//
// =================================================================

module debouncer #(
    parameter DEBOUNCE_CYCLES = 5
)(
    input wire clk,
    input wire reset,
    input wire noisy_button,
    output wire clean_pulse
);

    // Your implementation goes here.
    //
    // 1. Define localparams for your FSM states (e.g., IDLE, DEBOUNCE, PRESSED).
    //
    // 2. Define registers for your state machine and counter.
    //
    // 3. Implement the sequential logic (`always @(posedge clk...)`) for the registers.
    //
    // 4. Implement the combinational logic (`always @(*)`) for the next-state
    //    and counter logic. This is where you will check if the button is
    //    still pressed during the DEBOUNCE state.
    //
    // 5. Implement the output logic to generate a single-cycle pulse.

    localparam IDLE = 2'b00, DEBOUNCE = 2'b01;

    reg state, next_state;
    reg [2:0] counter;


    always @(posedge clk or posedge reset) begin
        if (reset)
            counter <= 0;
        else if (state == DEBOUNCE)
            if(counter == DEBOUNCE_CYCLES)
                counter <= 0; // Hold the counter value
            else
                counter <= counter + 1;
        else
            counter <= 0;
    end

    always @(*) begin
        case (state)
            IDLE:
                if (!noisy_button)
                    next_state = DEBOUNCE;
            DEBOUNCE:
                if(noisy_button)
                    next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    assign clean_pulse = (counter == DEBOUNCE_CYCLES && !noisy_button);

endmodule

