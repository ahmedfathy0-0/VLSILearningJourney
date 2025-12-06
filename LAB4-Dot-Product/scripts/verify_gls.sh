#!/bin/bash

# --- Configuration ---
TESTBENCH_FILE="src/dot_product_stream_tb.v"
RUN_TAG=stream_run # Your run tag
USERNAME=ahmedfathy0-0 # Your username
PDK_VERSION="0fe599b2afb6708d281543108caf8310912f54af" # The specific PDK version hash

# --- Paths ---
RTL_FILE="src/dot_product_stream.v"
NETLIST_FILE="runs/${RUN_TAG}/12-yosys-synthesis/dot_product_stream.nl.v"
FINAL_NL_FILE="runs/${RUN_TAG}/final/nl/dot_product_stream.nl.v"
PDK_ROOT="/home/${USERNAME}/.volare/volare/sky130/versions/${PDK_VERSION}"
STD_CELL_VERILOG="${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v"
PRIMITIVES_VERILOG="${PDK_ROOT}/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v"

# --- Output ---
RTL_EXECUTABLE="gls_sim_rtl.vvp"
NETLIST_EXECUTABLE="gls_sim_nl.vvp"
FINAL_NL_EXECUTABLE="gls_sim_final_nl.vvp"

# --- Check if files exist ---
if [ ! -f "$TESTBENCH_FILE" ]; then
    echo "ERROR: Testbench file not found: $TESTBENCH_FILE"
    exit 1
fi
if [ ! -f "$NETLIST_FILE" ]; then
    echo "ERROR: Synthesized netlist not found: $NETLIST_FILE"
    exit 1
fi
if [ ! -f "$STD_CELL_VERILOG" ]; then
    echo "ERROR: Standard cell Verilog not found: $STD_CELL_VERILOG"
    exit 1
fi
if [ ! -f "$PRIMITIVES_VERILOG" ]; then
    echo "ERROR: Primitives Verilog not found: $PRIMITIVES_VERILOG"
    exit 1
fi


# --- Compile ---
echo "Compiling Gate-Level Simulation..."
# run_gls.sh — replace the iverilog line with:
iverilog -g2012 -o ${FINAL_NL_EXECUTABLE} \
  -Wnone \
  -DFUNCTIONAL -DUNIT_DELAY=#1 \
  ${TESTBENCH_FILE} \
  ${FINAL_NL_FILE} \
  ${STD_CELL_VERILOG} \
  ${PRIMITIVES_VERILOG}


# Check if compilation was successful
if [ $? -ne 0 ]; then
    echo "ERROR: iverilog compilation failed."
    exit 1
fi

echo "Compilation successful: ${OUTPUT_EXECUTABLE}"

# --- Run ---
echo "Running Gate-Level Simulation..."
vvp ${FINAL_NL_EXECUTABLE}

# Check simulation exit status
if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed or exited with non-zero status."
    exit 1
fi

echo "Simulation finished successfully."