`timescale 1ns / 1ps

module dot_product_tb;

    // --- Configuration ---
    parameter WIDTH = 8;
    parameter N     = 4; // Testing a 4-element vector

    // --- Signals ---
    reg clk;
    reg rst_n;
    
    // Handshake
    reg input_valid;
    wire input_ready;
    
    // Data
    reg [(WIDTH*N)-1:0] A_vec;
    reg [(WIDTH*N)-1:0] B_vec;
    
    // Output
    wire [(2*WIDTH + $clog2(N)) - 1 : 0] result;
    wire output_valid;

    // --- Instantiate the DUT ---
    dot_product #(
        .WIDTH(WIDTH),
        .N(N)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .A_vec(A_vec),
        .B_vec(B_vec),
        .result(result),
        .output_valid(output_valid)
    );

    // --- Clock Generation (10ns period) ---
    always #5 clk = ~clk;

    // --- Test Sequence ---
    initial begin
        // Setup VCD for Surfer
        $dumpfile("dot_product_waves.vcd");
        $dumpvars(0, dot_product_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        input_valid = 0;
        A_vec = 0;
        B_vec = 0;

        // Reset Pulse
        #20 rst_n = 1;
        #10;

        $display("=== Starting Dot Product Verification ===");

        // ------------------------------------------------------------
        // Test Case 1: Identity / Simple
        // A = [1, 1, 1, 1], B = [1, 1, 1, 1]
        // Exp = 1+1+1+1 = 4
        // ------------------------------------------------------------
        // Note: Vectors are packed {A3, A2, A1, A0}
        verify_vector(
            {8'd1, 8'd1, 8'd1, 8'd1}, 
            {8'd1, 8'd1, 8'd1, 8'd1}, 
            4
        );

        // ------------------------------------------------------------
        // Test Case 2: Weighted Sum
        // A = [1, 2, 3, 4], B = [10, 1, 0, 2]
        // Exp = (1*2) + (2*0) + (3*1) + (4*10)  <-- Check LSB/MSB ordering!
        // Let's assume standard packing: A[0] is LSB. 
        // A_vec = {4, 3, 2, 1} (0x04030201)
        // B_vec = {2, 0, 1, 10} (0x0200010A)
        // Result = (1*10) + (2*1) + (3*0) + (4*2) = 10 + 2 + 0 + 8 = 20
        // ------------------------------------------------------------
        verify_vector(
            {8'd4, 8'd3, 8'd2, 8'd1}, 
            {8'd2, 8'd0, 8'd1, 8'd10}, 
            20
        );

        // ------------------------------------------------------------
        // Test Case 3: Zero Multiplication
        // A = [Random], B = [0, 0, 0, 0]
        // Exp = 0
        // ------------------------------------------------------------
        verify_vector(
            {8'd55, 8'd33, 8'd22, 8'd11}, 
            {32'd0}, 
            0
        );

        // ------------------------------------------------------------
        // Test Case 4: Max Saturation (Overflow Check)
        // A = [255, 255, 255, 255], B = [1, 1, 1, 1]
        // Exp = 255 + 255 + 255 + 255 = 1020
        // ------------------------------------------------------------
        verify_vector(
            {4{8'd255}}, 
            {4{8'd1}}, 
            1020
        );

        $display("=== All Tests Passed ===");
        #50;
        $finish;
    end

    // --- Robust Handshake Task ---
    task verify_vector(
        input [(WIDTH*N)-1:0] a_in, 
        input [(WIDTH*N)-1:0] b_in, 
        input [31:0] expected_val
    );
        begin
            // 1. Setup Data on the Bus
            @(posedge clk);
            A_vec <= a_in;
            B_vec <= b_in;
            input_valid <= 1;

            // 2. Wait for Ready (Backpressure Handling)
            // If the DUT is busy (Sequential), input_ready will be 0.
            // We hold input_valid=1 until input_ready becomes 1.
            while (input_ready == 0) begin
                @(posedge clk);
            end

            // 3. Transaction Occurs Here
            // At this clock edge, Valid=1 and Ready=1. The DUT takes the data.
            @(posedge clk);
            input_valid <= 0; // Drop valid so we don't send it twice

            // 4. Wait for Result
            wait(output_valid == 1);
            
            // 5. Check Result
            if (result !== expected_val) begin
                $display("FAIL");
                $display("   A: %h, B: %h", a_in, b_in);
                $display("   Expected: %d, Got: %d", expected_val, result);
                $stop; // Stop simulation on error
            end else begin
                $display("PASS: Result = %d", result);
            end

            // 6. Wait for handshake to finish (optional cleanup)
            @(posedge clk);
        end
    endtask

endmodule