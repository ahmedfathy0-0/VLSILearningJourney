// Power-optimized NxN Matrix-by-Vector Multiplier (Verilog-2005)
// Reworked from provided baseline: register enables, operand isolation, conditional accumulation.
// Keep functional behavior identical to baseline (same I/O, outputs, and sequencing).
//
// Save as: src/matrix_vector_multiplier.v
// NOTE: Comments with "// LOW-POWER CHANGE" indicate the targeted optimization and why.

module matrix_vector_multiplier #(
    parameter N     = 3, // Matrix/Vector dimension (e.g., 3 for 3x3)
    parameter WIDTH = 8  // Bit-width for each element
)(
    input  wire                   clk,
    input  wire                   rst_n,   // Active-low asynchronous reset
    input  wire                   ena,     // Enable signal to start multiplication

    // PARAMETERIZED Input Ports
    input  wire signed [N*N*WIDTH-1:0] matrix_a,
    input  wire signed [N*WIDTH-1:0]   vector_b,

    // PARAMETERIZED Output Ports
    output reg  signed [N*WIDTH-1:0]   vector_c,
    output reg                         done     // High when the result is ready
);

    // --- INTERNAL PARAMETERS ---
    localparam CNT_WIDTH = (N <= 1) ? 1 : $clog2(N); // handle small N safely
    localparam ACCUM_WIDTH = (2 * WIDTH) + ((N <= 1) ? 1 : $clog2(N));

    // --- INTERNAL STORAGE ---
    // Note: these are registers (flops) synthesized from the sequential blocks below.
    reg signed [WIDTH-1:0]       mat_a_reg [0:N-1][0:N-1];
    reg signed [WIDTH-1:0]       vec_b_reg [0:N-1];
    reg signed [ACCUM_WIDTH-1:0] vec_c_internal [0:N-1];

    // --- FSM AND COUNTERS ---
    reg [1:0] state;
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_LOAD    = 2'b01;
    localparam STATE_COMPUTE = 2'b11;
    localparam STATE_DONE    = 2'b10;

    // Parameterized loop counters (used as indices)
    reg [CNT_WIDTH-1:0] i;
    reg [CNT_WIDTH-1:0] k;

    // integer loop variables for generate-style unpack/pack in procedural blocks
    reg [CNT_WIDTH-1:0] row, col; // Loop iterators for loading/storing

    // --- CLOCK ENABLE SIGNALS (register-enable style gating) ---
    // LOW-POWER CHANGE: create local CE signals so registers update only when needed.
    wire load_ce    = (state == STATE_LOAD);    // used to load matrix & vector registers
    wire compute_ce = (state == STATE_COMPUTE); // used to update accumulator
    wire done_ce    = (state == STATE_DONE);    // used to pack output once

    // --- OPERAND ISOLATION / MULTIPLIER INPUTS ---
    // LOW-POWER CHANGE: provide isolated operands to the multiplier (zero when not computing).
    // We'll compute product combinationally only for the active i,k to avoid wide fanout switching.
    wire signed [WIDTH-1:0] a_isolated = (compute_ce) ? mat_a_reg[i][k] : {WIDTH{1'b0}};
    wire signed [WIDTH-1:0] b_isolated = (compute_ce) ? vec_b_reg[k]    : {WIDTH{1'b0}};

    // multiply into full width (2*WIDTH) then sign-extend to ACCUM_WIDTH
    wire signed [2*WIDTH-1:0] mul_full;
    assign mul_full = a_isolated * b_isolated;

    wire signed [ACCUM_WIDTH-1:0] product;
    assign product = {{(ACCUM_WIDTH-2*WIDTH){mul_full[2*WIDTH-1]}}, mul_full};

    // --- SEQUENTIAL: reset & load into internal registers (with CE) ---
    // LOW-POWER CHANGE: registers only change while their CE is asserted, reducing toggles.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers to zero
            for (row = 0; row < N; row = row + 1) begin
                for (col = 0; col < N; col = col + 1) begin
                    mat_a_reg[row][col] <= {WIDTH{1'b0}};
                end
                vec_b_reg[row] <= {WIDTH{1'b0}};
                vec_c_internal[row] <= {ACCUM_WIDTH{1'b0}};
            end
            // reset FSM & counters
            done <= 1'b0;
            vector_c <= {N*WIDTH{1'b0}};
        end else begin
            // --- LOAD stage ---
            if (load_ce) begin
                // LOW-POWER CHANGE: load registers only when in LOAD state.
                // This prevents the matrix/vector flops from toggling in other states.
                for (row = 0; row < N; row = row + 1) begin
                    for (col = 0; col < N; col = col + 1) begin
                        mat_a_reg[row][col] <= matrix_a[(row*N+col)*WIDTH +: WIDTH];
                    end
                    vec_b_reg[row] <= vector_b[row*WIDTH +: WIDTH];
                    vec_c_internal[row] <= {ACCUM_WIDTH{1'b0}}; // clear accumulator at load
                end
            end

            // --- COMPUTE stage: update a single accumulator per cycle with operand isolation ---
            if (compute_ce) begin
                // LOW-POWER CHANGE: conditional accumulation avoids toggling when operands are zero.
                // Only update vec_c_internal[i] if the operands are both non-zero.
                // This reduces internal switching for adders and the accumulator flop.
                if ((mat_a_reg[i][k] != {WIDTH{1'b0}}) && (vec_b_reg[k] != {WIDTH{1'b0}})) begin
                    vec_c_internal[i] <= vec_c_internal[i] + product;
                end else begin
                    // Keep the register value unchanged to avoid toggling.
                    vec_c_internal[i] <= vec_c_internal[i];
                end
            end

            // --- DONE stage: pack outputs only in DONE (single-cycle write) ---
            if (done_ce) begin
                // LOW-POWER CHANGE: write to vector_c only once in DONE state to reduce bus toggles.
                for (row = 0; row < N; row = row + 1) begin
                    // Truncate accumulator to WIDTH (same behavior as baseline)
                    vector_c[row*WIDTH +: WIDTH] <= vec_c_internal[row][WIDTH-1:0];
                end
                done <= 1'b1;
            end else begin
                // keep done low except the single DONE cycle
                if (state != STATE_DONE) begin
                    done <= 1'b0;
                end
            end
        end
    end

    // --- FSM & index progression (separate block for clarity) ---
    // Keep FSM behavior same as baseline, but progress counters only in compute state.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            i <= {CNT_WIDTH{1'b0}};
            k <= {CNT_WIDTH{1'b0}};
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (ena) begin
                        state <= STATE_LOAD;
                    end else begin
                        state <= STATE_IDLE;
                    end
                end

                STATE_LOAD: begin
                    // After the LOAD cycle completes, start COMPUTE with indices reset.
                    i <= {CNT_WIDTH{1'b0}};
                    k <= {CNT_WIDTH{1'b0}};
                    state <= STATE_COMPUTE;
                end

                STATE_COMPUTE: begin
                    // Progress inner/outer loop indices similar to baseline.
                    if (k == N-1) begin
                        k <= {CNT_WIDTH{1'b0}};
                        if (i == N-1) begin
                            i <= {CNT_WIDTH{1'b0}};
                            state <= STATE_DONE;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        k <= k + 1;
                    end
                end

                STATE_DONE: begin
                    // After DONE, return to IDLE (vector_c written in the other sequential block)
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    // --- Note on global clock gating & CE ---
    // We used register-enable style gating (CE signals) in the sequential logic above.
    // This is synthesis-friendly: synthesis tools will either keep the enables
    // as gating logic or map them to integrated clock-gating cells if available.
    // This is preferred over manual gating of 'clk' in RTL (which is unsafe/unsupported).
    //
    // If you want stronger gating, enable the synthesis tool's clock-gating or
    // allow ECO to insert dedicated clock-gating cells based on these enables.

endmodule
