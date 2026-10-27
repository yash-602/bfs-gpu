# bfs-gpu: Adaptive Load-Balanced CUDA BFS (Group 17)

PCAP mini project: *Adaptive Load-Balanced CUDA-Based Breadth-First Search for Graph Processing*
(CUDA + OpenMP). Three BFS programs, serial CPU, naive CUDA and adaptive CUDA, are compared on road,
social and R-MAT graphs.

| # | Member | Role | Name (fill in) |
|---|--------|------|----------------|
| 1 | Member 1 | Foundation, data & verification | `<Member 1 name, roll no.>` |
| 2 | Member 2 | Naive CUDA, benchmark harness & evaluation | `<Member 2 name, roll no.>` |
| 3 | Member 3 | Adaptive load-balanced CUDA BFS | `<Member 3 name, roll no.>` |

## Project status: what still has to be delivered

- **Member 1** (contract, host library, tools, tests, datasets, scripts): complete.
- **Member 2** (naive CUDA BFS + test, `bench`, `run_all.sh`, `analyze.py`): code complete; the GPU
  experiments (E2, E4-E6) and report section 5 wait for a run on a GPU.
- **Member 3** (adaptive CUDA BFS): not delivered yet. Until then, run experiments with `IMPL=naive`.

The files below are still **placeholders** written by Member 1 so the repository builds. Each one says at the
top what goes in it and which playbook section holds the code. List the remaining ones with:

```bash
grep -rl "PLACEHOLDER-NOT-YET-DELIVERED" src tests scripts docs
```

| File | Owner | Playbook section | Done when |
|------|-------|------------------|-----------|
| `src/bfs_adaptive.cu` | Member 3 | M3 9.4 | `./bin/test_adaptive` prints `TEST_ADAPTIVE: PASS` |
| `tests/test_adaptive.cu` | Member 3 | M3 9.5 | same |
| `docs/adaptive_design.md` | Member 3 | M3 9.9, 9.14 | final defaults written down (H7) |
| `docs/report/*` sections marked PLACEHOLDER | M2 / M3 | report outline 8.2 | section written |

While `src/bfs_adaptive.cu` is a placeholder, `bench --impl both` stops with an error when it reaches the
adaptive program; use `--impl naive` (or `IMPL=naive bash scripts/run_all.sh`).

To deliver: overwrite the placeholder file completely with your version (same path and name), then run
`bash scripts/check_all.sh`.

## Requirements

Linux (or WSL2), g++ >= 9 with OpenMP, GNU make >= 3.82, CUDA toolkit >= 11.5 and an NVIDIA GPU,
Python 3 with pandas, matplotlib and numpy (for the analysis only). On Windows use WSL2 and keep the
repository inside the Linux filesystem (`~/bfs-gpu`), not under `/mnt/c/...` (playbook section 4.2).

## Running on Google Colab (no local NVIDIA GPU)

1. Open the notebook straight from GitHub:
   https://colab.research.google.com/github/yash-602/bfs-gpu/blob/main/colab/bfs_colab.ipynb
2. *Runtime -> Change runtime type -> T4 GPU*, then *Runtime -> Run all*.

The notebook clones this repository, builds for the detected GPU, runs the host tests, `hello_cuda`, the
golden-value check and `scripts/check_all.sh`, downloads the datasets, records `results/env.txt`, runs the
experiments and `analyze.py`, and downloads `results/` as a zip. (Without GitHub access, use the zip-upload
cell instead; `python scripts/make_zip.py` makes `../bfs-gpu.zip`.)
Colab GPUs differ between sessions: final experiments must all run in one session (playbook 4.3).

## Build

```bash
make host                       # CPU tools and tests (no GPU needed)
make gpu ARCH=native            # CUDA programs (use ARCH=sm_XX if 'native' is not accepted)
bash scripts/check_all.sh       # builds and runs every test; prints ALL CHECKS PASSED
```

`make test` runs only the host unit tests (expected last line: `39 checks passed, 0 failed`).

## Data

```bash
bash scripts/download_datasets.sh && bash scripts/convert_all.sh   # about 15 GB disk, 6 GB free RAM for com-orkut
```

This downloads the SNAP graphs into `data/raw/`, converts them to binary CSR files in `data/csr/`, and
generates `rmat15` ... `rmat22`. `data/` is never committed. Graph statistics are in `docs/dataset_table.md`.

## Command-line tool (host only)

```bash
./bin/graph_tool convert data/raw/roadNet-CA.txt data/csr/roadNet-CA.csr   # text -> binary CSR
./bin/graph_tool rmat 18 16 1 data/csr/rmat18.csr                          # scale, edge factor, seed
./bin/graph_tool stats data/csr/rmat18.csr                                 # degree stats, diameter
./bin/graph_tool serial data/csr/rmat18.csr 5                              # serial BFS from 5 sources
```

## Run one experiment

```bash
./bin/bench --graph data/csr/rmat18.csr --category rmat --impl both --structural --out results/demo.csv
```

(all options: `./bin/bench` with no arguments)

## Reproduce all results and figures

```bash
bash scripts/env_report.sh > results/env.txt
bash scripts/run_all.sh
python3 scripts/analyze.py          # writes results/tables.md and results/figs/*.png
bash scripts/omp_scaling.sh data/raw/com-youtube.ungraph.txt > results/omp_scaling.csv   # E7
python3 scripts/plot_omp_scaling.py # writes results/figs/fig_omp_scaling.png
```

## Layout

| Path | Owner | Content |
|------|-------|---------|
| `include/` | M1 | frozen contract headers (types, CSR graph, BFS API, validators, CUDA helpers, GPU test suite) |
| `src/graph_io.cpp graph_gen.cpp bfs_serial.cpp validate.cpp graph_stats.cpp` | M1 | host library |
| `src/bfs_naive.cu bench.cu` | M2 | naive GPU BFS, benchmark driver |
| `src/bfs_adaptive.cu` | M3 | adaptive GPU BFS |
| `tools/graph_tool.cpp` | M1 | convert / rmat / stats / serial |
| `tests/` | M1 / M2 / M3 | `hello_cuda.cu`, `test_host.cpp` (M1), `test_naive.cu` (M2), `test_adaptive.cu` (M3) |
| `scripts/` | M1 / M2 | data, environment, checks, E7, `make_zip.py` (M1); `run_all.sh`, `analyze.py` (M2) |
| `colab/bfs_colab.ipynb` | M1 | Google Colab notebook: build, check, datasets, environment record |
| `docs/` | all | `decisions.md`, `dataset_table.md` (M1), `adaptive_design.md` (M3), `report/` |
| `data/` | not in git | `raw/` downloaded text graphs, `csr/` binary graphs |
| `results/` | M2 | CSVs from `bench`, `figs/` from `analyze.py` |

The contract (`include/*` plus the CSV schema) changes only through the procedure in playbook section 3.4.

## Results shown in the report were produced on

`<GPU, CPU, RAM, CUDA, driver, g++>`, git commit `<hash>` (see `results/env.txt`).
