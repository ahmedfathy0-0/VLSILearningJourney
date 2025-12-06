module dot_product_stream #(
    parameter WIDTH  = 8,  // Bit width of a single element
    parameter N = 4   // Number of elements in the vector
)(
    input  wire clk,
    input  wire rst_n,
    
    // --- Handshake Interface ---
    input  wire input_valid,
    
    // --- Data Inputs ---
    // Flattened Vectors: [ (WIDTH*N)-1 : 0 ]
    // Example: For 4x8-bit, this is [31:0]
    input  wire [WIDTH-1:0] A_vec,
    input  wire [WIDTH-1:0] B_vec,
    
    // --- Output ---
    // Accumulator Size = (2 * WIDTH) + log2(N) to prevent overflow
    output reg  [(2*WIDTH + $clog2(N)) - 1 : 0] result,
    output reg  output_valid
);

    // --- Internal Storage ---
    reg [WIDTH-1:0] A_reg;
    reg [WIDTH-1:0] B_reg;

    reg [(2*WIDTH + $clog2(N)) - 1 : 0] multiply_result;
    reg last_input;
    reg last_input_mul_add;
    
    // --- Control Logic ---
    // Counter needs enough bits to count up to N
    reg [$clog2(N)-1:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_valid <= 1'b0;
            result  <= 0;
            multiply_result  <= 0;
            counter      <= 0;
            A_reg <= 0; B_reg <= 0;

            last_input <= 0;
            last_input_mul_add <= 0;
        end else begin

            if (input_valid) begin
                A_reg <= A_vec;
                B_reg <= B_vec;

                if(counter == N - 1) begin
                    counter <= 0;
                    last_input <= 1;
                end else
                    counter <= counter + 1;

            end else begin
                A_reg <= 0;
                B_reg <= 0;
                last_input <= 0;
            end

            multiply_result <= A_reg * B_reg;
            last_input_mul_add <= last_input;

            result <= result + multiply_result;
            output_valid <= last_input_mul_add;
        end
    end

endmodule