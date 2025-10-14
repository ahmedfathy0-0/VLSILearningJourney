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

    localparam IDLE = 2'b00, DEBOUNCE = 2'b01, PRESSED = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] counter;
    reg clean_pulse_reg;


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            clean_pulse_reg <= 0;
        end else begin
            if (state == DEBOUNCE) begin
                counter <= counter + 1;
            end else begin
                counter <= 0;
            end
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (!noisy_button) begin
                    next_state = DEBOUNCE;
                end else begin
                    next_state = IDLE;
                end
            end
            DEBOUNCE: begin
                if(noisy_button) begin
                    next_state = IDLE;
                end else if (counter == DEBOUNCE_CYCLES-1) begin
                    next_state = PRESSED;
                end else begin
                    next_state = DEBOUNCE;
                end
            end
            PRESSED: begin
                next_state = PRESSED;
            end
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    // always @(*) begin
    //     clean_pulse_reg = 0;
    //     if (state == PRESSED && counter == 0) begin
    //         clean_pulse_reg = 1;
    //     end
    // end

    always @(*) begin

        if (state == PRESSED) begin
            next_state <= IDLE;
            clean_pulse_reg <= 1;
        end else begin
            clean_pulse_reg <= 0;
        end

    end

    assign clean_pulse = clean_pulse_reg;

endmodule

