# Appendix A: Reproduction instructions

*(Owner: Member 1.)*

Everything in this report can be regenerated from the tagged commit `final` with the commands below, on a
Linux (or WSL2) machine with g++ >= 9, GNU make >= 3.82, CUDA >= 11.5, an NVIDIA GPU and Python 3 with pandas,
matplotlib and numpy. On WSL2 keep the repository in the Linux filesystem (`~/bfs-gpu`).

```bash
git clone <repository URL> bfs-gpu && cd bfs-gpu
git checkout final

# 1. build and prove correctness (last line must be: ALL CHECKS PASSED)
make all ARCH=native            # or ARCH=sm_XX, see playbook section 4.4
bash scripts/check_all.sh

# 2. data: SNAP graphs + R-MAT scales 15..22 (about 15 GB disk, 6 GB free RAM for com-orkut)
bash scripts/download_datasets.sh
bash scripts/convert_all.sh
./bin/graph_tool stats data/csr/rmat18.csr    # must show 88105 isolated vertices, max degree 25096, CV 6.473

# 3. record the machine, run all experiments, regenerate tables and figures
bash scripts/env_report.sh > results/env.txt
bash scripts/run_all.sh
python3 scripts/analyze.py

# 4. E7: host-side OpenMP scaling
bash scripts/omp_scaling.sh data/raw/com-youtube.ungraph.txt > results/omp_scaling.csv
python3 scripts/plot_omp_scaling.py
```

Determinism: all graphs and source vertices are generated with seed 1. R-MAT graphs are bit-identical for
any number of OpenMP threads, so `cmp` of two `rmat18.csr` files made with different `OMP_NUM_THREADS` prints
nothing. Golden values (playbook 6.7): R-MAT CSR entry counts for scales 15..22 are 883,014; 1,818,618;
3,730,760; 7,612,566; 15,481,582; 31,402,974; 63,545,062; 128,313,944.
