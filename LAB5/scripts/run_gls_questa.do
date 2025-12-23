# ============================================================================
# Post-Synthesis Gate-Level Simulation with FULL SDF Timing
# For QuestaSim / ModelSim with Sky130 PDK
# ============================================================================

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
puts "Compiling with TIMING models (no FUNCTIONAL)"
puts "============================================"

# Compile WITHOUT +define+FUNCTIONAL to keep timing specify blocks
# -suppress 2892: implicit net declarations
# -suppress 13522: specify path issues in PDK (QuestaSim quirk)
vlog -work work -suppress 2892 -suppress 13522 ${PRIMITIVES_VERILOG}
vlog -work work -suppress 2892 -suppress 13522 ${STD_CELL_VERILOG}
vlog -work work ${NETLIST_FILE}
vlog -work work ${RTL_DIR}/traffic_light_tb.v

# --- Run Simulation ---
puts "============================================"
puts "Starting Simulation with FULL SDF Timing"
puts "============================================"

# Load simulation with SDF - timing will be applied properly
vsim -t 1ps \
     -voptargs="+acc" \
     -suppress 3009 -suppress 3722 \
     -sdfmax /traffic_light_tb/uut=${SDF_FILE} \
     -sdfnoerror \
     -wlf gls_timing.wlf \
     work.traffic_light_tb

# --- Add Waveforms ---
add wave -divider "Clock & Reset"
add wave -color "Yellow" /traffic_light_tb/clk
add wave -color "Red" /traffic_light_tb/reset

add wave -divider "Inputs"
add wave /traffic_light_tb/sensor_north
add wave /traffic_light_tb/sensor_east
add wave -radix unsigned /traffic_light_tb/config_time

add wave -divider "Light Outputs (Check Delays Here)"
add wave -color "Green" /traffic_light_tb/light_ns
add wave -color "Cyan" /traffic_light_tb/light_ew

add wave -color "Green" /traffic_light_tb/uut/5light_ns
add wave -color "Cyan" /traffic_light_tb/light_ew

add wave -divider "Internal State"
quietly catch {add wave /traffic_light_tb/uut/current_state}
quietly catch {add wave -radix unsigned /traffic_light_tb/uut/timer}

# Run simulation
run 600ns
wave zoom full

puts ""
puts "============================================"
puts "TIMING Simulation Complete!"
puts "============================================"
puts "Now you should see REAL delays from the SDF file."
puts "Zoom in on clock edges to measure clk-to-Q delays."
puts "============================================"
