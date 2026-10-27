# Preliminary results: Google Colab, Tesla T4, 2026-10-27

**Preliminary.** Use these to start writing and to design the report's figures and tables; replace them with the
final run before submission (playbook 6.6: final numbers come from one machine, one session, one commit).

| | |
|---|---|
| Machine | Google Colab, NVIDIA Tesla T4 (40 SMs, CC 7.5, 15 GB), Intel Xeon @ 2.00 GHz (2 logical CPUs), 12 GB RAM (`env.txt`, `gpu_info.txt`) |
| Code | commit `a88c3f5`, built with `ARCH=sm_75 OPT=-O3`, CUDA 13.0, g++ 13.3 |
| Command | `SRC=2 TRIALS=2 IMPL=naive bash scripts/run_all.sh E2 E5 E6`, then `python3 scripts/analyze.py` |
| Implementations | serial and naive only (the adaptive program was still a placeholder) |
| Experiments | E2 (2 sources x 2 trials), E5 and E6 (3 sources x 3 trials); E3 and E4 not run |
| Correctness | 392 rows, 0 failed verification; also `test_host` 39/39, `hello_cuda` PASS, `TEST_NAIVE: PASS` (12 configurations) |

The raw CSVs (`E2_main.csv`, `E5_weak.csv`, `E6_block.csv`) are byte-identical copies of the files written by
`bench` in the Colab session (MD5 checked). `tables.md`, `summary_*.csv` and `figs/` were regenerated from them
with `python scripts/analyze.py --results results/colab_t4_2026-10-27_preliminary`.

For the final run: same notebook, `SRC=5 TRIALS=5`, experiments `E2 E3 E4 E5 E6`, and the adaptive program in place.
