// POWER-OPT: Operand Isolation + clean enables (clock-gating friendly)
module matrix_vector_multiplier #(
    parameter N     = 3,
    parameter WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,   // Active-low async reset
    input  wire                   ena,     // Start pulse/level

    input  wire signed [N*N*WIDTH-1:0] matrix_a,
    input  wire signed [N*WIDTH-1:0]   vector_b,

    output reg  signed [N*WIDTH-1:0]   vector_c,
    output reg                         done
);

    // --- INTERNAL PARAMETERS ---
    localparam CNT_WIDTH   = (N <= 1) ? 1 : $clog2(N);
    localparam ACCUM_WIDTH = (2*WIDTH) + $clog2(N);

    // --- INTERNAL STORAGE ---
    reg signed [WIDTH-1:0]       mat_a [0:N-1][0:N-1];
    reg signed [WIDTH-1:0]       vec_b [0:N-1];
    reg signed [ACCUM_WIDTH-1:0] vec_c_internal [0:N-1];

    // --- FSM ---
    reg [1:0] state;
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_LOAD    = 2'b01;
    localparam STATE_COMPUTE = 2'b10;
    localparam STATE_DONE    = 2'b11;

    // --- Counters ---
    reg [CNT_WIDTH-1:0] i, k;
    reg [CNT_WIDTH-1:0] row, col;

    // --- Enables (for fine-grained gating) ---
    wire load_en    = (state == STATE_LOAD);
    wire compute_en = (state == STATE_COMPUTE);
    wire done_en    = (state == STATE_DONE);

    // --- Operand Isolation ---
    // Keep multiplier inputs at 0 unless actually computing this MAC.
    // This is synthesized as AND-gates / muxes on the operand buses.
    wire signed [WIDTH-1:0] iso_a = compute_en ? mat_a[i][k] : '0;
    wire signed [WIDTH-1:0] iso_b = compute_en ? vec_b[k]    : '0;

    // Optional: short-circuit the adder when a zero operand is detected.
    // This avoids toggling in the accumulator adder when the product is 0.
    wire prod_is_zero = (iso_a == '0) || (iso_b == '0);
    wire signed [2*WIDTH-1:0] product = iso_a * iso_b;

    integer r, c; // for generate-style loops below

    // --- SEQUENTIAL ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            done  <= 1'b0;
            i     <= '0;
            k     <= '0;

            // Reset accumulators (using named loop vars to avoid synthesis warnings)
            for (r = 0; r < N; r = r + 1) begin
                vec_c_internal[r] <= '0;
            end

            // (Leaving mat_a/vec_b uninitialized on reset is fine; they are loaded in STATE_LOAD)
        end else begin
            // Default “hold” to avoid unnecessary toggles
            done <= 1'b0;

            case (state)
                // ---------------- IDLE ----------------
                STATE_IDLE: begin
                    if (ena) begin
                        i <= '0;
                        k <= '0;
                        for (r = 0; r < N; r = r + 1) begin
                            vec_c_internal[r] <= '0;
                        end
                        state <= STATE_LOAD;
                    end
                end

                // ---------------- LOAD ----------------
                STATE_LOAD: begin
                    // Only write when loading (write-enable serves as clock-gating hint)
                    if (load_en) begin
                        for (row = 0; row < N; row = row + 1) begin
                            for (col = 0; col < N; col = col + 1) begin
                                mat_a[row][col] <= matrix_a[(row*N+col)*WIDTH +: WIDTH];
                            end
                            vec_b[row] <= vector_b[row*WIDTH +: WIDTH];
                            vec_c_internal[row] <= '0;
                        end
                        i <= '0;
                        k <= '0;
                    end
                    state <= STATE_COMPUTE;
                end

                // ---------------- COMPUTE ----------------
                STATE_COMPUTE: begin
                    // MAC with operand isolation:
                    // If product is zero, skip accumulator write to avoid toggling.
                    if (!prod_is_zero) begin
                        vec_c_internal[i] <= vec_c_internal[i] + {{(ACCUM_WIDTH-(2*WIDTH)){product[2*WIDTH-1]}}, product};
                    end
                    // If product is zero, we hold vec_c_internal[i] (no write).

                    // Counter progression
                    if (k == N-1) begin
                        k <= '0;
                        if (i == N-1) begin
                            i <= '0;
                            state <= STATE_DONE;
                        end else begin
                            i <= i + 1'b1;
                        end
                    end else begin
                        k <= k + 1'b1;
                    end
                end

                // ---------------- DONE ----------------
                STATE_DONE: begin
                    if (done_en) begin
                        for (row = 0; row < N; row = row + 1) begin
                            // Truncate/saturate policy: here we truncate to WIDTH
                            vector_c[row*WIDTH +: WIDTH] <= vec_c_internal[row][WIDTH-1:0];
                        end
                        done  <= 1'b1;
                    end
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule