`timescale 1ns / 1ps

module dot_product_stream_tb;

    // --- Configuration ---
    localparam WIDTH = 8;
    localparam N     = 4; // Testing a 4-element vector

    // --- Signals ---
    reg clk;
    reg rst_n;
    reg input_valid;
    reg [WIDTH-1:0] A_vec;
    reg [WIDTH-1:0] B_vec;

    wire [(2*WIDTH + $clog2(N)) - 1 : 0] result;
    wire output_valid;

        dot_product_stream dut (
            .clk(clk),
            .rst_n(rst_n),
            .input_valid(input_valid),
            .A_vec(A_vec),
            .B_vec(B_vec),
            .result(result),
            .output_valid(output_valid)
        );

    // --- Clock Generation (10ns period) ---
    always #5 clk = ~clk;

    // --- Simple reset helper ---
    task automatic reset_dut;
        begin
            rst_n       <= 1'b0;
            input_valid <= 1'b0;
            A_vec       <= {WIDTH{1'b0}};
            B_vec       <= {WIDTH{1'b0}};
            repeat (3) @(posedge clk);
            rst_n <= 1'b1;
            @(posedge clk);
        end
    endtask

    // --- Scalar driver: feeds one element per cycle ---
    task automatic drive_scalar_vector(
        input [(WIDTH*N)-1:0] a_flat,
        input [(WIDTH*N)-1:0] b_flat
    );
        integer idx;
        begin
            for (idx = 0; idx < N; idx = idx + 1) begin
                @(posedge clk);
                input_valid <= 1'b1;
                A_vec       <= a_flat[idx*WIDTH +: WIDTH];
                B_vec       <= b_flat[idx*WIDTH +: WIDTH];
            end
            @(posedge clk);
            input_valid <= 1'b0; // self-drain begins here
            A_vec       <= {WIDTH{1'b0}};
            B_vec       <= {WIDTH{1'b0}};
        end
    endtask

    // --- Wait for output and check self-drain timing ---
    task automatic wait_for_result(
        input integer min_delay_cycles,
        input integer max_delay_cycles,
        output integer observed_delay
    );
        begin
            observed_delay = 0;
            while (output_valid !== 1'b1) begin
                @(posedge clk);
                observed_delay = observed_delay + 1;
                if (observed_delay > max_delay_cycles) begin
                    $display("FAIL: output_valid did not assert within %0d cycles", max_delay_cycles);
                    $stop;
                end
            end
            if (observed_delay < min_delay_cycles) begin
                $display("FAIL: output_valid asserted too early (delay %0d < %0d)", observed_delay, min_delay_cycles);
                $stop;
            end
        end
    endtask

    // --- Test runner ---
    task automatic run_test(
        input [(WIDTH*N)-1:0] a_flat,
        input [(WIDTH*N)-1:0] b_flat,
        input [31:0] expected_val,
        input [127:0] test_name
    );
        integer drain_delay;
        begin
            reset_dut();
            drive_scalar_vector(a_flat, b_flat);
            wait_for_result(2, N + 5, drain_delay); // self-draining check

            // Sample result on the cycle output_valid is high
            if (result !== expected_val) begin
                $display("FAIL: %s exp=%0d got=%0d (delay=%0d cycles)", test_name, expected_val, result, drain_delay);
                $stop;
            end else begin
                $display("PASS: %s result=%0d (delay=%0d cycles)", test_name, result, drain_delay);
            end
            @(posedge clk);
        end
    endtask

    // --- Test Sequence ---
    initial begin
        // Setup VCD for Surfer
        $dumpfile("dot_product_stream_waves.vcd");
        $dumpvars(0, dot_product_stream_tb);

        // Initialize
        clk         = 1'b0;
        rst_n       = 1'b0;
        input_valid = 1'b0;
        A_vec       = {WIDTH{1'b0}};
        B_vec       = {WIDTH{1'b0}};

        $display("=== Starting Dot Product Stream Verification ===");

        // Test Case 1: Identity / Simple
        // A = [1, 1, 1, 1], B = [1, 1, 1, 1], Exp = 4
        run_test(
            {8'd1, 8'd1, 8'd1, 8'd1},
            {8'd1, 8'd1, 8'd1, 8'd1},
            4,
            "identity"
        );

        // Test Case 2: Weighted Sum
        // A = [1, 2, 3, 4], B = [10, 1, 0, 2], Exp = 20
        run_test(
            {8'd4, 8'd3, 8'd2, 8'd1},
            {8'd2, 8'd0, 8'd1, 8'd10},
            20,
            "weighted_sum"
        );

        // Test Case 3: Zero Multiplication
        // A = [random], B = [0, 0, 0, 0], Exp = 0
        run_test(
            {8'd55, 8'd33, 8'd22, 8'd11},
            {32'd0},
            0,
            "zero_mult"
        );

        // Test Case 4: Max Saturation / Overflow Check
        // A = [255, 255, 255, 255], B = [1, 1, 1, 1], Exp = 1020
        run_test(
            {4{8'd255}},
            {4{8'd1}},
            1020,
            "saturation"
        );

        $display("=== All Stream Tests Passed ===");
        #50;
        $finish;
    end

endmodule