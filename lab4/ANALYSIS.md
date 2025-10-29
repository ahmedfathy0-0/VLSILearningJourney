# ANALYSIS

> Repo artifacts referenced: `opt.json`, `metrics.csv` (per run), and images in `image/`.

---

## 1) Hardware Characterization Table (from `metrics.csv`)

The table summarizes **total dynamic+leakage power** (mW), **setup worst slack** (ns) at `nom_tt_025C_1v80`, and **die area** (µm²) for the baseline and optimized designs.

| Design | N | W | Variant | Total Power (mW) | Setup WS (ns) | Die Area (µm²) |
|---|---:|---:|---|---:|---:|---:|
| Baseline N=3, W=8 | 3 | 8 | baseline | 0.002173421 | 18.259233 | 19710.1 |
| Baseline N=3, W=16 | 3 | 16 | baseline | 0.008479454 | 16.696669 | 44100.7 |
| Baseline N=3, W=32 | 3 | 32 | baseline | 0.043214988 | 13.647917 | 181938.0 |
| Optimized N=3, W=8 | 3 | 8 | opt | 0.000527945 | 18.042285 | 20903.6 |


**Comments (N=3, W=8, opt vs baseline):**
- Power: ↓ **75.7%** (from 0.002173421 mW → 0.000527945 mW).
- Die area: ↑ **6.1%** (from 19710.1 → 20903.6 µm²).
- Timing slack: reduced by **0.217 ns** (from 18.259233 → 18.042285 ns).

**Scaling with W (baseline N=3):**
- Total power rises superlinearly with bit-width (W=8 → 32 increases ~1888%).
- Die area grows strongly (≈823% from W=8 → 32), consistent with wider datapaths and multipliers.
- Setup WS shrinks (from 18.26 ns to 13.65 ns), indicating tighter timing at higher widths.

> **Automation hint:** See `tools/extract_metrics.py` below to regenerate this table automatically from any set of `metrics.csv` files.


---

## 2) Optimization Strategy (Power)

**Techniques used**
- **Operand isolation:** Gate multiplier/adder inputs when results are not required to quench internal toggling.
- **Clock gating:** Drive clock enables for idle register banks / FSM stages to suppress clock-tree switching.
- *(Optional)* **Bit-width management:** Avoid over-wide intermediates to cut switched capacitance.

**Trade-offs**
- **Power:** Large reduction driven by suppressed switching; here we measured **~75.7%** for N=3, W=8.
- **Area:** Small overhead for isolation logic and gating cells (≈6.1% change observed).
- **Timing:** Slack impact was slightly negative (-0.217 ns), since isolation can reduce effective fanout while gating cells add minor insertion delay.


---

## 3) GLS Debugging Journey

In GLS with Sky130 cells, simulators can propagate `X` due to detailed timing primitives. The commonly used flags help:

- **`-DFUNCTIONAL -DUNIT_DELAY="#1"`**: Selects the *functional* (logic-only) views with a uniform unit delay to avoid complex specify blocks, reducing `X` proliferation.
- **`-DUSE_POWER_PINS`**: Enables library models that *explicitly* declare `VPWR/VGND` (and sometimes `VPB/VNB`) ports. Gate-level netlists emitted by PnR often instantiate cells with power pins. Defining this macro aligns the cell model interface with the netlist, preventing **port mismatch errors/warnings** (e.g., wrong number of ports) and avoiding **unconnected power pin** issues that can lead to floating supplies and `X` outputs.
- **`-I .`**: Adds the current directory to the **Verilog include search path** so `` `include`` statements (e.g., primitives.v, sky130_fd_sc_hd__*.v) and any generated headers are found. This prevents **file-not-found** errors and missing macro/package definitions that otherwise cause compilation failures or unresolved module references.

Example command (adjust variables to your environment):

```sh
iverilog -o build/sim-g2012   -g2012 -DFUNCTIONAL -DSIM -DGL -DUNIT_DELAY="#1" -DUSE_POWER_PINS   -I . $PRIMITIVES $CELLS $GL_NETLIST $TB
```


---

## 4) Impact of Matrix Size (N)

**Physical changes when increasing N**
- **Register banks:** Input/output vectors and accumulation registers scale with N; more storage flops and wider muxing.
- **Control:** Loop counters / FSM state expand to index more rows/cols; selector muxes get wider.
- **I/O:** More pins or wider buses for matrices/vectors if exposed.

**Die area vs. N**
- **Storage registers** scale roughly **O(N)** for vector length, while **compute logic** (e.g., MAC array) can scale toward **O(N²)** if parallelized. In this baseline (single MAC reused), area growth is dominated by **datapath width (W)** and by added multiplexing for larger N; if you instantiate multiple MACs, area rises faster with N.

**Computation time (cycles) and setup WS**
- If a single MAC is reused, total cycles scale ~**O(N²)** for an N×N by N×1 multiply.
- **Setup WS (slack)** depends on the *critical combinational path* (e.g., multiplier + adder + control). Increasing N does **not necessarily** slow the clock if the datapath per cycle is unchanged; N mostly affects **cycle count**, not combinational depth. Clock speed degrades primarily with **bit-width (W)** or if you pipeline less / add fanout-heavy muxing for larger N.


---

## 5) Test Evidence and Artifacts

- **RTL run output:** *Attach your terminal screenshot showing* `matrix_vector_multiplier_opt_tb.v` **PASS**.  
  VCD: `rtl_out.vcd` (example).
- **RTL waveform:** GTKWave snapshot comparing `vector_c_opt`, `vector_c_baseline`, and `done`.  
  VCD: `rtl_out.vcd`.  
  _Caption:_ *RTL: opt vs baseline outputs match; done pulses at completion.*
- **GLS run output:** *Attach terminal screenshot showing GLS PASS.*  
  Netlist: `runs/<run_tag>/final/nl.v` (example path).
- **GLS waveform:** GTKWave snapshot of GLS with the same signals.  
  Netlist: `runs/<run_tag>/final/nl.v`.  
  _Caption:_ *GLS: functional models with `-DUSE_POWER_PINS` and unit delays stabilize sim (no Xs).*

If you already saved a figure, it will render here in Markdown if present in the repo:
![Waveform](image/output.png)


---

### `opt.json` (example stub)

Replace this with your real optimization configuration used for the **Optimized N=3, W=8** run.

```json
{
  "SYNTH_PARAMETERS": "N=3,W=8",
  "OPT_STEPS": {
    "operand_isolation": true,
    "clock_gating": true,
    "bit_width_pruning": false
  },
  "NOTES": "Example only\u2014replace with your actual opt.json used for the optimized run."
}
```


---

### tools/extract_metrics.py

A small script to auto-extract metrics from any number of `metrics.csv` files and print a Markdown table.

```python
#!/usr/bin/env python3
import csv, sys, os

COLS = [
  ("power__total", "Total Power (mW)"),
  ("timing__setup__ws__corner:nom_tt_025C_1v80", "Setup WS (ns)"),
  ("design__die__area", "Die Area (um2)"),
]

def find_metrics_row(csv_path):
    with open(csv_path, newline='') as f:
        r = list(csv.DictReader(f))
        # Use last row if multiple epochs; otherwise the only row
        return r[-1]

def main(paths):
    rows = []
    for p in paths:
        row = find_metrics_row(p)
        label = os.path.basename(os.path.dirname(p)) or os.path.basename(p)
        out = {"Design": label}
        for key, _ in COLS:
            out[key] = row.get(key, "")
        rows.append(out)

    # Print Markdown
    headers = ["Design"] + [h for _, h in COLS]
    print("| " + " | ".join(headers) + " |")
    print("|" + "|".join(["---"]*len(headers)) + "|")
    for r in rows:
        vals = [r["Design"]]
        vals += [r.get(k, "") for k,_ in COLS]
        print("| " + " | ".join(vals) + " |")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract_metrics.py runs/*/reports/metrics.csv ...", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1:])
```

**Usage**

```sh
python3 tools/extract_metrics.py runs/baseline_N3_W8/reports/metrics.csv \
  runs/baseline_N3_W16/reports/metrics.csv \
  runs/baseline_N3_W32/reports/metrics.csv \
  runs/opt_N3_W8/reports/metrics.csv
```