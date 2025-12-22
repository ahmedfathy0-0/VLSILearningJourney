# ==============================================================================
# TIMING CONSTRAINTS
# Goal: 238 MHz Frequency (Sweet Spot for Pass/Fail)
# ==============================================================================

# 1. Define the Clock
# Period = 4.2ns.
# The unoptimized logic path (Adder + Comparator) takes approx 4.8ns in Sky130 HD.
# The optimized logic (Carry Lookahead + Flattened) takes approx 3.8ns.
# Therefore, 4.2ns is the perfect "Sweet Spot" to demonstrate optimization.
create_clock -name clk -period 4.2 [get_ports clk]

# 2. I/O Constraints (The "Squeeze")
# We pretend inputs arrive 1.0ns late and outputs must be ready 1.0ns early.
# Effective Budget for Logic = 4.2ns - 1.0ns - 1.0ns = 2.2ns.
# This forces the synthesis tool to work extremely hard on the 'time_limit' calculation.
set_input_delay -max 1.0 -clock [get_clocks clk] [get_ports sensor_north]
set_output_delay -max 1.0 -clock [get_clocks clk] [get_ports light_ns]

# 3. Uncertainty (Jitter)
# Real-world margin.
set_clock_uncertainty 0.2 [get_clocks clk]
