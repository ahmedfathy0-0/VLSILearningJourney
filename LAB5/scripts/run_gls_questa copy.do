# ============================================================================
# Post-Synthesis Gate-Level Simulation with SDF Back-Annotation
# For QuestaSim / ModelSim with Sky130 PDK
# ============================================================================

# --- Quit any existing simulation ---
quietly catch {quit -sim}

# --- Configuration ---
set RUN_TAG "run_final"
set USERNAME "ahmedfathy0-0"
set PDK_VERSION "0fe599b2afb6708d281543108caf8310912f54af"

# --- Paths ---
set BASE_DIR "/home/${USERNAME}/Documents/CMP27/VLSI/VLSILearningJourney/LAB5"
set PDK_ROOT "/home/${USERNAME}/.volare/volare/sky130/versions/${PDK_VERSION}"

set RTL_DIR "${BASE_DIR}/src"
set NETLIST_FILE "${BASE_DIR}/runs/${RUN_TAG}/final/nl/traffic_light.nl.v"
set SDF_FILE "${BASE_DIR}/runs/${RUN_TAG}/final/sdf/nom_tt_025C_1v80/traffic_light__nom_tt_025C_1v80.sdf"
set STD_CELL_VERILOG "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v"
set PRIMITIVES_VERILOG "${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v"

# --- Create work library ---
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# --- Compile Design ---
puts "============================================"
puts "Compiling Post-Synthesis Gate-Level Netlist"
puts "============================================"

# Compile primitives first (required by standard cells)
vlog -work work -suppress 2892 +define+FUNCTIONAL +define+UNIT_DELAY=#1 ${PRIMITIVES_VERILOG}

# Compile standard cell library
vlog -work work -suppress 2892 +define+FUNCTIONAL +define+UNIT_DELAY=#1 ${STD_CELL_VERILOG}

# Compile the post-synthesis netlist
vlog -work work ${NETLIST_FILE}

# Compile the testbench
vlog -work work ${RTL_DIR}/traffic_light_tb.v

# --- Run Simulation ---
puts "============================================"
puts "Starting Simulation with SDF Back-Annotation"
puts "============================================"

# Load simulation with SDF
# +acc=npr preserves signal access for waveform viewing
# -voptargs=+acc disables optimization to keep signal visibility
vsim -t 1ps \
     -voptargs="+acc" \
     +notimingchecks \
     -suppress 3009 -suppress 3722 \
     -sdfmax /traffic_light_tb/uut=${SDF_FILE} \
     -sdfnoerror \
     -wlf gls_sim.wlf \
     work.traffic_light_tb

# --- Add Waveforms ---
# Clock and Reset
add wave -divider "Clock & Reset"
add wave -color "Yellow" /traffic_light_tb/clk
add wave -color "Red" /traffic_light_tb/reset

# Inputs
add wave -divider "Inputs"
add wave /traffic_light_tb/sensor_north
add wave /traffic_light_tb/sensor_east
add wave -radix unsigned /traffic_light_tb/config_time

# Light Outputs (Key signals for delay measurement)
add wave -divider "Light Outputs"
add wave -color "Green" /traffic_light_tb/light_ns
add wave -color "Cyan" /traffic_light_tb/light_ew

# Internal UUT signals for glitch detection
add wave -divider "Internal State (UUT)"
quietly catch {add wave /traffic_light_tb/uut/current_state}
quietly catch {add wave /traffic_light_tb/uut/next_state}
quietly catch {add wave -radix unsigned /traffic_light_tb/uut/timer}

# Run simulation
run 600ns

# Zoom to see full waveform
wave zoom full

puts ""
puts "============================================"
puts "Simulation Complete!"
puts "============================================"
puts ""
puts "INSTRUCTIONS FOR YOUR LAB:"
puts ""
puts "1. MEASURING DELAYS:"
puts "   - Zoom in on a clock rising edge"
puts "   - Use cursors: View -> Cursors -> Two Cursors"
puts "   - Place cursor 1 on clk rising edge"
puts "   - Place cursor 2 on output (light_ns/light_ew) change"
puts "   - Read the delta time shown"
puts ""
puts "2. LOOKING FOR GLITCHES:"
puts "   - Zoom to ~1ns resolution"
puts "   - Look for brief spikes on outputs"
puts "   - Compare with RTL simulation (no glitches)"
puts "============================================"
