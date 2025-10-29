// This module is a NON-SYNTHESIZABLE, synchronous behavioral model.
// It uses `repeat` and event controls to model the debouncer's behavior
// in a cycle-accurate way, but without describing implementable hardware.
module debouncer_tb #(
    parameter DEBOUNCE_CYCLES = 5
)(
    input wire clk,
    input wire reset,
    input wire noisy_button,
    output reg clean_pulse
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clean_pulse <= 1'b0;
        end else begin
            // Default to pulse low
            clean_pulse <= 1'b0;

            // Wait for a button press (negedge)
            if (noisy_button == 1'b0) begin
                
                // This is the non-synthesizable part. A real FSM would
                // use a counter. This `repeat` block is for simulation only.
                repeat(DEBOUNCE_CYCLES) @(posedge clk);

                // After waiting, if the button is still pressed, it's valid.
                if (noisy_button == 1'b0) begin
                    clean_pulse <= 1'b1;
                end
            end
        end
    end

endmodule

