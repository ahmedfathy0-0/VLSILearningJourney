// Synthesizable NxN Matrix by Nx1 Vector Multiplication Accelerator
// (Fully parameterized, Verilog-2005 compatible)

module matrix_vector_multiplier_baseline #(
    parameter N     = 3, // Matrix/Vector dimension (e.g., 3 for 3x3)
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
    
    // Calculate the width for our loop counters (e.g., for N=3, we need 2 bits)
    localparam CNT_WIDTH = $clog2(N);

    // Calculate the width for the internal accumulator
    // Product width = WIDTH * WIDTH => 2*WIDTH
    // We add N of these products. Sum can grow by $clog2(N) bits.
    localparam ACCUM_WIDTH = (2 * WIDTH) + $clog2(N);

    // --- INTERNAL STORAGE ---
    
    // PARAMETERIZED 2D register for the matrix and 1D for the vectors
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
    reg [CNT_WIDTH-1:0] i, k;    // Loop indices for rows and inner product
    reg [CNT_WIDTH-1:0] row, col; // Loop iterators for loading/storing

    // On every clock cycle, manage the state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // --- RESET STATE ---
            state <= STATE_IDLE;
            done  <= 1'b0;
            i     <= 0;
            k     <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (ena) begin
                        state <= STATE_LOAD; // Start on enable signal
                    end
                end

                STATE_LOAD: begin
                    // --- LOAD AND UNPACK INPUTS ---
                    // This 'for' loop is unrolled by the synthesizer
                    for (row = 0; row < N; row = row + 1) begin
                        for (col = 0; col < N; col = col + 1) begin
                            // PARAMETERIZED unpacking logic
                            mat_a[row][col] <= matrix_a[(row*N+col)*WIDTH +: WIDTH];
                        end
                        vec_b[row] <= vector_b[row*WIDTH +: WIDTH];
                        vec_c_internal[row] <= 0; // Clear previous result
                    end
                    i <= 0;
                    k <= 0;
                    state <= STATE_COMPUTE;
                end

                STATE_COMPUTE: begin
                    // --- PERFORM ONE MULTIPLY-ACCUMULATE PER CYCLE ---
                    // C[i] = C[i] + A[i][k] * B[k]
                    vec_c_internal[i] <= vec_c_internal[i] + (mat_a[i][k] * vec_b[k]);

                    // --- PARAMETERIZED LOOP COUNTER UPDATE ---
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
                    // --- PACK 1D RESULT VECTOR INTO OUTPUT ---
                    // This 'for' loop is also unrolled
                    for (row = 0; row < N; row = row + 1) begin
                        // PARAMETERIZED packing logic
                        // NOTE: This truncates the wide accumulator result!
                        vector_c[row*WIDTH +: WIDTH] <= vec_c_internal[row][WIDTH-1:0];
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
