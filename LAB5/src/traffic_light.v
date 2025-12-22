module traffic_light (
    input wire clk, reset,
    input wire sensor_north,      // Sensor inputs add logic depth
    input wire sensor_east,
    input wire [7:0] config_time, // Base time value
    output reg [2:0] light_ns,
    output reg [2:0] light_ew
);
    localparam RED=3'b100, YELLOW=3'b010, GREEN=3'b001;
    reg [2:0] state, next_state;
    reg [7:0] timer;

    // --- CRITICAL PATH START ---
    // This wire represents a chain of MUXes triggered by the sensors.
    // Logic Depth:
    // 1. (sensor_north && sensor_east) -> AND gate
    // 2. (sensor_north || sensor_east) -> OR gate
    // 3. MUX to select between config_time or (config_time + 20)
    // 4. ADDER (+ 20)
    // Total: ~2-3ns of combinational logic just to calculate 'time_limit'.
    wire [7:0] time_limit = (sensor_north && sensor_east) ? config_time :
                            (sensor_north || sensor_east) ? (config_time + 8'd20) :
                            config_time; //

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            state <= 0; 
            timer <= 0; 
        end else begin
            // --- CRITICAL PATH END ---
            // The calculated 'time_limit' enters a COMPARATOR (>=).
            // Comparator logic is slow (bitwise XORs and ANDs).
            // Path: Mux -> Adder -> Comparator -> Register Setup.
            // If the clock is faster than ~4.2ns, this path will FAIL setup timing
            // unless the tool flattens and optimizes aggressively.
            if (timer >= time_limit) begin 
                state <= next_state; 
                timer <= 0; 
            end else 
                timer <= timer + 1; //
        end
    end

    // Standard Finite State Machine (FSM) Output Logic
    // This part is fast and rarely causes timing violations.
    always @(*) begin
        case (state)
            0: next_state = 1; 1: next_state = 2;
            2: next_state = 3; 3: next_state = 0;
            default: next_state = 0;
        endcase
        light_ns = RED; light_ew = RED;
        case (state)
            0: light_ns = GREEN; 1: light_ns = YELLOW;
            2: light_ew = GREEN; 3: light_ew = YELLOW;
        endcase
    end
endmodule
