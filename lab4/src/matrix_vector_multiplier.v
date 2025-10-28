// STUDENT TO COMPLETE THIS MODULE
//
// This file is a template for your power-optimized accelerator.
//
// GOAL:
// Re-implement the matrix-vector multiplier to achieve the *lowest possible power consumption*.
// Your focus should be on reducing *dynamic power* (switching power).
//
// CONCEPTS TO CONSIDER:
// Think about when computation is truly necessary. Can you prevent unnecessary
// switching activity in the datapath or stop the clock to idle components?
// Techniques like **Operand Isolation** and **Clock Gating** are commonly used.
//
// BASELINE BEHAVIOR:
// The code below implements the baseline functionality correctly, but without
// any specific power optimizations. Use it as your starting point.
//

module matrix_vector_multiplier #(
    parameter N     = 3, // Matrix/Vector dimension
    parameter WIDTH = 8  // Bit-width for each element
)(
    input  wire                   clk,
    input  wire                   rst_n,   // Active-low asynchronous reset
    input  wire                   ena,     // Enable signal to start multiplication

    // PARAMETERIZED Input Ports
    // Flat bus for the NxN matrix: (N*N*WIDTH) total bits
    input  wire signed [N*N*WIDTH-1:0] matrix_a,
    // Flat bus for the Nx1 vector: (N*WIDTH) total bits
    input  wire signed [N*WIDTH-1:0]   vector_b,

    // PARAMETERIZED Output Ports
    // Flat bus for the Nx1 result: (N*WIDTH) total bits
    output reg  signed [N*WIDTH-1:0]   vector_c,
    output reg                         done     // High when the result is ready
);

// --- INTERNAL PARAMETERS ---
    // Calculate the width for our loop counters
    localparam CNT_WIDTH = $clog2(N);
    // Calculate the width for the internal accumulator
    localparam ACCUM_WIDTH = (2 * WIDTH) + $clog2(N);

// --- INTERNAL STORAGE ---
    // Baseline stores inputs internally. Consider if this is needed for power opt.
    reg signed [WIDTH-1:0]       mat_a [0:N-1][0:N-1];
    reg signed [WIDTH-1:0]       vec_b [0:N-1];
    reg signed [ACCUM_WIDTH-1:0] vec_c_internal [0:N-1]; // Wider for accumulation

// --- FSM AND COUNTERS ---
    reg [1:0] state;
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_LOAD    = 2'b01;
    localparam STATE_COMPUTE = 2'b10;
    localparam STATE_DONE    = 2'b11;

    // PARAMETERIZED loop counters
    reg [CNT_WIDTH-1:0] i, k;     // Loop indices for rows and inner product
    reg [CNT_WIDTH-1:0] row, col; // Loop iterators for loading/storing

    // On every clock cycle, manage the state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // --- RESET STATE ---
            state <= STATE_IDLE;
            done  <= 1'b0;
            i     <= 0;
            k     <= 0;
            // Ensure all state-holding elements are reset
            for (row = 0; row < N; row = row + 1) begin
                 vec_c_internal[row] <= 0;
                 // Reset internal storage if used
                 // vec_b[row] <= 0;
                 // for (col = 0; col < N; col = col + 1) begin
                 //    mat_a[row][col] <= 0;
                 // end
            end
        end else begin
            // --- FSM LOGIC ---
            // Consider if the entire FSM needs to run when idle (ena=0)
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0; // Ensure done is low in idle
                    if (ena) begin
                        // Initialize necessary counters/registers for starting
                        i <= 0;
                        k <= 0;
                        for (row = 0; row < N; row = row + 1) begin
                             vec_c_internal[row] <= 0; // Clear accumulator
                        end
                        state <= STATE_LOAD; // Default transition from baseline
                    end
                end

                STATE_LOAD: begin
                    // Baseline loads inputs into internal registers.
                    // Is this load state necessary for power optimization?
                    for (row = 0; row < N; row = row + 1) begin
                        for (col = 0; col < N; col = col + 1) begin
                            mat_a[row][col] <= matrix_a[(row*N+col)*WIDTH +: WIDTH];
                        end
                        vec_b[row] <= vector_b[row*WIDTH +: WIDTH];
                        vec_c_internal[row] <= 0; // Clear previous result (Redundant if cleared in IDLE)
                    end
                    i <= 0; // Redundant if cleared in IDLE
                    k <= 0; // Redundant if cleared in IDLE
                    state <= STATE_COMPUTE;
                end

                STATE_COMPUTE: begin
                    // Baseline performs one MAC unconditionally.
                    // Can unnecessary computation (e.g., multiply by zero) be avoided?
                    vec_c_internal[i] <= vec_c_internal[i]
                        + (mat_a[i][k] * vec_b[k]);

                    // Baseline counter logic
                    if (k == N-1) begin
                        k <= 0;
                        if (i == N-1) begin
                            i <= 0;
                            state <= STATE_DONE; // Finished all computations
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        k <= k + 1;
                    end
                end

                STATE_DONE: begin
                    // Baseline packs the result vector and signals completion.
                    for (row = 0; row < N; row = row + 1) begin
                        vector_c[row*WIDTH +: WIDTH] <= vec_c_internal[row][WIDTH-1:0]; // Truncate result
                    end
                    done  <= 1'b1;
                    state <= STATE_IDLE; // Return to idle
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule