`timescale 1ns/1ps

// Testbench for verifying either the RTL or a synthesized netlist
// of the matrix_vector_multiplier module against expected values.
module matrix_vector_multiplier_synth_tb;

    // -------- Parameters --------
    localparam integer N          = 3;
    localparam integer WIDTH      = 8;
    localparam integer CLK_PERIOD = 25;

    // Derived widths
    localparam integer MATRIX_A_WIDTH = N*N*WIDTH;
    localparam integer VECTOR_B_WIDTH = N*WIDTH;
    localparam integer VECTOR_C_WIDTH = N*WIDTH;

    // -------- DUT I/O --------
    reg                      clk;
    reg                      rst_n;
    reg                      ena;
    reg  signed [MATRIX_A_WIDTH-1:0] matrix_a;  // flattened N×N matrix input
    reg  signed [VECTOR_B_WIDTH-1:0] vector_b;  // flattened N vector input

    wire signed [VECTOR_C_WIDTH-1:0] vector_c_dut; // DUT Output
    wire                             done_dut;     // DUT Done signal

    // -------- Instantiate the DUT --------
    // This instance will be bound to EITHER the RTL source file OR the netlist
    // during compilation, based on the files provided to the simulator.
    matrix_vector_multiplier dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .ena      (ena),
        .matrix_a (matrix_a),
        .vector_b (vector_b),
        .vector_c (vector_c_dut),
        .done     (done_dut)
    );

    // -------- Clock --------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

  // -------- Simple reset task --------
  task do_reset;
  begin
	$display("[%0t] Asserting reset (rst_n = 0)", $time);
    rst_n    = 1'b0;
    ena      = 1'b0;
    matrix_a = {MATRIX_A_WIDTH{1'b0}};
    vector_b = {VECTOR_B_WIDTH{1'b0}};
    // Wait a few cycles with reset asserted
    repeat (5) @(posedge clk); // Increased hold time slightly, just in case
	
	// Deassert reset slightly *after* the clock edge
	@(posedge clk);
	#1; // Wait a small delay (e.g., 1ps) after the edge
    rst_n = 1'b1;
    @(posedge clk);
	$display("[%0t] Deasserting reset (rst_n = 1)", $time);
	
	// Wait for at least one full clock cycle before proceeding
	@(posedge clk);
	$display("[%0t] Reset sequence complete.", $time);
  end
  endtask

    // -------- Apply stimulus and check against expected --------
    task apply_and_check(
        input signed [MATRIX_A_WIDTH-1:0] m,
        input signed [VECTOR_B_WIDTH-1:0] v,
        input signed [VECTOR_C_WIDTH-1:0] expected_c,
        input reg [159:0]                 test_name // 20 chars * 8 bits
    );
        begin
            $display("[%0t] Starting Test Case: %s", $time, test_name);
            // Drive inputs
            matrix_a <= m;
            vector_b <= v;

            // Pulse enable for one cycle
            @(posedge clk);
            ena <= 1'b1;
            @(posedge clk);
            ena <= 1'b0;

            // Wait for the DUT to assert done
            wait (done_dut == 1'b1); // Wait until done_dut is high
            @(posedge clk); // Allow output to settle

            // Compare result against expected value
            if (vector_c_dut === expected_c) begin
                $display("  >> %s PASSED!", test_name);
			end
            else begin
                $display("  >> %s FAILED!", test_name);
                $display("     Expected C: %0d (0x%0h)", $signed(expected_c),   expected_c);
                $display("     DUT Gave C: %0d (0x%0h)", $signed(vector_c_dut), vector_c_dut);
                $fatal; // Stop simulation on failure
            end
        end
    endtask

    // -------- Test Vectors --------
    // Values are assigned within the initial block
    reg signed [MATRIX_A_WIDTH-1:0] matrix_a_tc1, matrix_a_tc2, matrix_a_tc3, matrix_a_tc4, matrix_a_tc5;
    reg signed [VECTOR_B_WIDTH-1:0] vector_b_tc1, vector_b_tc2, vector_b_tc3, vector_b_tc4, vector_b_tc5;
    reg signed [VECTOR_C_WIDTH-1:0] expected_c_tc1, expected_c_tc2, expected_c_tc3, expected_c_tc4, expected_c_tc5;

    // -------- Test sequence --------
    initial begin
        // Waves
        $dumpfile("synth_tb_waves.vcd");
        $dumpvars(0, matrix_vector_multiplier_synth_tb);

        // Reset
        do_reset();

        // ========== Packing convention ==========
        // MSB-first: {row0[0], row0[1]..row0[N-1], row1[0]..row1[N-1], .. rowN-1[N-1]}
        // MSB-first: {b0, b1..bN-1}

        // -------- TC1: Simple Positive Values --------
        $display("---- TC1: simple positive ----");
        matrix_a_tc1 = { 8'sd1,  8'sd2,  8'sd3,    // Row 0
                         8'sd4,  8'sd5,  8'sd6,    // Row 1
                         8'sd7,  8'sd8,  8'sd9 };   // Row 2
        vector_b_tc1 = { 8'sd1,  8'sd2,  8'sd3 };   // b = [1,2,3]
        // C[0] = 1*1 + 2*2 + 3*3 = 14
        // C[1] = 4*1 + 5*2 + 6*3 = 32
        // C[2] = 7*1 + 8*2 + 9*3 = 50
        expected_c_tc1 = {8'sd14, 8'sd32, 8'sd50}; // {C0, C1, C2}
        apply_and_check(matrix_a_tc1, vector_b_tc1, expected_c_tc1, "Simple Positive");

        // -------- TC2: Identity Matrix --------
        $display("---- TC2: identity * vector ----");
        matrix_a_tc2 = { 8'sd1,  8'sd0,  8'sd0,    // Row 0
                         8'sd0,  8'sd1,  8'sd0,    // Row 1
                         8'sd0,  8'sd0,  8'sd1 };   // Row 2
        vector_b_tc2 = { 8'sd2,  8'sd7,  8'sd99 };  // b = [2,7,99]
        expected_c_tc2 = {8'sd2,  8'sd7,  8'sd99}; // {C0, C1, C2} = b
        apply_and_check(matrix_a_tc2, vector_b_tc2, expected_c_tc2, "Identity * Vector");

        // -------- TC3: Zero Vector --------
        $display("---- TC3: zero vector ----");
        matrix_a_tc3 = { 8'sd33, 8'sd22, 8'sd85,
                         8'sd11, 8'sd99, 8'sd45,
                         8'sd77, 8'sd66, 8'sd19 };
        vector_b_tc3 = { 8'sd0, 8'sd0, 8'sd0 };     // b = [0,0,0]
        expected_c_tc3 = {8'sd0, 8'sd0, 8'sd0};     // {C0, C1, C2} = 0
        apply_and_check(matrix_a_tc3, vector_b_tc3, expected_c_tc3, "Zero Vector");

        // -------- TC4: Min/Max Stress (signed) --------
        $display("---- TC4: min/max signed ----");
        // A rows: [-127 -127 -127], [-1 -1 1], [127 127 127]
        matrix_a_tc4 = { -8'sd127, -8'sd127, -8'sd127, // Row 0
                         -8'sd1,   -8'sd1,    8'sd1,   // Row 1
                          8'sd127,  8'sd127,  8'sd127}; // Row 2
        vector_b_tc4 = {  8'sd127,  8'sd127,  8'sd127}; // b = [127,127,127]
        // C[0] = -48387 -> truncates to -3 (0xFD)
        // C[1] = -127 -> fits (0x81)
        // C[2] = 48387 -> truncates to 3 (0x03)
        expected_c_tc4 = {8'shFD, 8'sh81, 8'sh03};   // {C0, C1, C2}
        apply_and_check(matrix_a_tc4, vector_b_tc4, expected_c_tc4, "Min/Max Signed");

        // -------- TC5: Mixed signs --------
        $display("---- TC5: mixed signs ----");
        // A = [[10,-3,5], [-8,12,0], [7,1,-2]]
        matrix_a_tc5 = {  8'sd10,  -8'sd3,   8'sd5,    // Row 0
                         -8'sd8,   8'sd12,   8'sd0,    // Row 1
                          8'sd7,   8'sd1,   -8'sd2 };   // Row 2
        vector_b_tc5 = { -8'sd4,   8'sd9,   8'sd3 };   // b = [-4, 9, 3]
        // C[0] = 10*(-4) + (-3)*9 + 5*3 = -40 - 27 + 15 = -52 (0xCC)
        // C[1] = (-8)*(-4) + 12*9 + 0*3 = 32 + 108 + 0 = 140 -> truncates to -116 (0x8C)
        // C[2] = 7*(-4) + 1*9 + (-2)*3 = -28 + 9 - 6 = -25 (0xE7)
        expected_c_tc5 = {8'shCC, 8'sh8C, 8'shE7};   // {C0, C1, C2}
        apply_and_check(matrix_a_tc5, vector_b_tc5, expected_c_tc5, "Mixed Signs");

        $display("[%0t] All tests passed.", $time);
        $finish;
    end

endmodule