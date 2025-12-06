module dot_product #(
    parameter WIDTH  = 8,  // Bit width of a single element
    parameter N = 4   // Number of elements in the vector
)(
    input  wire clk,
    input  wire rst_n,
    
    // --- Handshake Interface ---
    input  wire input_valid,
    output reg  input_ready,
    
    // --- Data Inputs ---
    // Flattened Vectors: [ (WIDTH*N)-1 : 0 ]
    // Example: For 4x8-bit, this is [31:0]
    input  wire [(WIDTH*N)-1:0] A_vec,
    input  wire [(WIDTH*N)-1:0] B_vec,
    
    // --- Output ---
    // Accumulator Size = (2 * WIDTH) + log2(N) to prevent overflow
    output reg  [(2*WIDTH + $clog2(N)) - 1 : 0] result,
    output reg  output_valid
);

    // --- Internal Storage ---
    reg [(WIDTH*N)-1:0] A_reg;
    reg [(WIDTH*N)-1:0] B_reg;
    
    // --- Control Logic ---
    // Counter needs enough bits to count up to N
    reg [$clog2(N)-1:0] counter;
    reg [1:0] state;
    
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_COMPUTE = 2'b01;
    localparam STATE_DONE    = 2'b10;

    // --- Dynamic Mux Logic (The "Cloud") ---
    // These wires hold the single element selected by the counter
    wire signed [WIDTH-1:0] a_element;
    wire signed [WIDTH-1:0] b_element;

    // "Indexed Part Select" Syntax: [START +: BLOCK_SIZE]
    // If counter is 0, grabs [0 +: 8] -> bits [7:0]
    // If counter is 1, grabs [8 +: 8] -> bits [15:8]
    assign a_element = A_reg[counter * WIDTH +: WIDTH];
    assign b_element = B_reg[counter * WIDTH +: WIDTH];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= STATE_IDLE;
            input_ready  <= 1'b0;
            output_valid <= 1'b0;
            result  <= 0;
            counter      <= 0;
            A_reg <= 0; B_reg <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    output_valid <= 1'b0;
                    input_ready  <= 1'b1;
                    
                    if (input_valid && input_ready) begin
                        A_reg       <= A_vec;
                        B_reg       <= B_vec;
                        input_ready <= 1'b0; // Lock inputs
                        result <= 0;    // Clear accumulator
                        counter     <= 0;
                        state       <= STATE_COMPUTE;
                    end
                end

                STATE_COMPUTE: begin
                    // 1. Multiply the selected elements and Add to total
                    // Note: This infers 1 Multiplier and 1 Adder reused N times
                    result <= result + (a_element * b_element);
                    
                    // 2. Loop Control
                    // Casting to clog2(N) bits to prevent width mismatch warnings
                    if (counter == $clog2(N)'(N - 1)) begin 
                        state <= STATE_DONE;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                STATE_DONE: begin
                    output_valid <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    // Fault Recovery: Go back to start
                    state        <= STATE_IDLE;
                    output_valid <= 1'b0;
                    input_ready  <= 1'b0; // Safety: Don't accept input while recovering
                end
            endcase
        end
    end

endmodule