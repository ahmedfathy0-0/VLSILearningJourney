`timescale 1ns/1ps

// Testbench compares the OPT design (matrix_vector_multiplier)
// against the baseline (matrix_vector_multiplier_baseline)
// using only Verilog-2001 constructs, no SV-only features.

module matrix_vector_multiplier_opt_tb;

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

  reg  signed [MATRIX_A_WIDTH-1:0] matrix_a;  // flattened N×N matrix
  reg  signed [VECTOR_B_WIDTH-1:0] vector_b;  // flattened N vector

  wire signed [VECTOR_C_WIDTH-1:0] vector_c_baseline;
  wire                             done_baseline;

  wire signed [VECTOR_C_WIDTH-1:0] vector_c_opt;
  wire                             done_opt;

  // -------- Instantiate Baseline DUT --------
  matrix_vector_multiplier_baseline #(
    .N(N), .WIDTH(WIDTH)
  ) dut_baseline (
    .clk      (clk),
    .rst_n    (rst_n),
    .ena      (ena),
    .matrix_a (matrix_a),
    .vector_b (vector_b),
    .vector_c (vector_c_baseline),
    .done     (done_baseline)
  );

  // -------- Instantiate Optimized DUT --------
  matrix_vector_multiplier #(
    .N(N), .WIDTH(WIDTH)
  ) dut_opt (
    .clk      (clk),
    .rst_n    (rst_n),
    .ena      (ena),
    .matrix_a (matrix_a),
    .vector_b (vector_b),
    .vector_c (vector_c_opt),
    .done     (done_opt)
  );

  // -------- Clock --------
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // -------- Simple reset task --------
  task do_reset;
  begin
    rst_n    = 1'b0;
    ena      = 1'b0;
    matrix_a = {MATRIX_A_WIDTH{1'b0}};
    vector_b = {VECTOR_B_WIDTH{1'b0}};
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  end
  endtask

  // -------- Apply one stimulus and check equality --------
  task apply_and_check(
    input signed [MATRIX_A_WIDTH-1:0] m,
    input signed [VECTOR_B_WIDTH-1:0] v
  );
  begin
    // Drive inputs
    matrix_a <= m;
    vector_b <= v;

    // Pulse enable for one cycle
    @(posedge clk);
    ena <= 1'b1;
    @(posedge clk);
    ena <= 1'b0;

    // Wait for both designs to assert done
    @(posedge done_opt or posedge done_baseline);
	@(posedge done_opt or posedge done_baseline);
    @(posedge clk);

    // Compare results (bit-accurate)
    if (vector_c_opt !== vector_c_baseline) begin
      $display("[%0t] FAIL", $time);
      $display("  baseline: %0d (0x%0h)", $signed(vector_c_baseline), vector_c_baseline);
      $display("  opt     : %0d (0x%0h)", $signed(vector_c_opt),      vector_c_opt);
      $fatal;
    end else begin
      $display("[%0t] PASS -> c = %0d (0x%0h)",
               $time, $signed(vector_c_opt), vector_c_opt);
    end
  end
  endtask

  // -------- Test sequence --------
  initial begin
    // Waves
    $dumpfile("opt_vs_baseline_waves.vcd");
    $dumpvars(0, matrix_vector_multiplier_opt_tb);

    // Reset
    do_reset();

    // ========== Packing convention ==========
    // We pack MSB-first in concatenations below.
    // For matrix_a: {a00, a01, a02, a10, a11, a12, a20, a21, a22}
    // For vector_b: {b0, b1, b2}
    // Make sure your DUTs use the same convention.

    // -------- TC1: Simple Positive Values --------
    $display("---- TC1: simple positive ----");
    apply_and_check(
      // A = [[1,2,3],[4,5,6],[7,8,9]]
      {
        8'sd1, 8'sd2, 8'sd3,
        8'sd4, 8'sd5, 8'sd6,
        8'sd7, 8'sd8, 8'sd9
      },
      // b = [1,2,3]
      { 8'sd1, 8'sd2, 8'sd3 }
    );

    // -------- TC2: Identity Matrix --------
    $display("---- TC2: identity * vector ----");
    apply_and_check(
      // A = I3
      {
        8'sd1, 8'sd0, 8'sd0,
        8'sd0, 8'sd1, 8'sd0,
        8'sd0, 8'sd0, 8'sd1
      },
      // b = [2,7,99]
      { 8'sd2, 8'sd7, 8'sd99 }
    );

    // -------- TC3: Zero Vector --------
    $display("---- TC3: zero vector ----");
    apply_and_check(
      {
        8'sd33, 8'sd22, 8'sd85,
        8'sd11, 8'sd99, 8'sd45,
        8'sd77, 8'sd66, 8'sd19
      },
      { 8'sd0, 8'sd0, 8'sd0 }
    );

    // -------- TC4: Min/Max Stress (signed) --------
    $display("---- TC4: min/max signed ----");
    // A rows: [-127 -127 -127], [-1 -1 1], [127 127 127]
    apply_and_check(
      {
        -8'sd127, -8'sd127, -8'sd127,
        -8'sd1,   -8'sd1,    8'sd1,
         8'sd127,  8'sd127,  8'sd127
      },
      { 8'sd127, 8'sd127, 8'sd127 }
    );

    // -------- TC5: Mixed signs --------
    $display("---- TC5: mixed signs ----");
    apply_and_check(
      {
         8'sd10,  -8'sd3,  8'sd5,
        -8'sd8,    8'sd12, 8'sd0,
         8'sd7,    8'sd1, -8'sd2
      },
      { -8'sd4, 8'sd9, 8'sd3 }
    );

    $display("[%0t] All tests passed.", $time);
    $finish;
  end

endmodule
