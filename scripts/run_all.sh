#!/usr/bin/env bash
# scripts/run_all.sh -- OWNER: Member 2.
# Runs the experiments and appends rows to results/*.csv
# Usage (repo root, after 'make gpu' and scripts/convert_all.sh):
#   bash scripts/run_all.sh            # all experiments
#   bash scripts/run_all.sh E2 E4      # only the listed ones
# Environment overrides: SRC (sources, default 5), TRIALS (default 5), SEED (default 1; Member 3 tunes with
# SEED=2), IMPL (default both; use IMPL=naive while src/bfs_adaptive.cu is still a placeholder).
set -euo pipefail
BENCH=./bin/bench
mkdir -p results
SMS=$($BENCH --gpu-info | awk -F= '/sm_count/{print $2}')
echo "GPU has $SMS SMs"; $BENCH --gpu-info > results/gpu_info.txt
SRC=${SRC:-5}; TRIALS=${TRIALS:-5}; SEED=${SEED:-1}; IMPL=${IMPL:-both}
declare -A CAT=( [roadNet-CA]=road [roadNet-PA]=road [com-youtube]=social
                 [soc-LiveJournal1]=social [com-orkut]=social )
MAIN_GRAPHS="roadNet-CA com-youtube soc-LiveJournal1 com-orkut rmat16 rmat18 rmat20 rmat22"
SCALE_GRAPHS="roadNet-CA soc-LiveJournal1 rmat22"  # one per category
cat_of() { if [[ "$1" == rmat* ]]; then echo rmat; else echo "${CAT[$1]}"; fi; }
want() {  # want E2 -> succeeds if E2 was requested on the command line
    for a in "${SELECT[@]}"; do [ "$a" == "$1" ] && return 0; done
    return 1
}
SELECT=("$@"); [ ${#SELECT[@]} -eq 0 ] && SELECT=(E1 E2 E3 E4 E5 E6)

run() { echo ">>> $*"; "$BENCH" "$@" --seed "$SEED"; }

# trace rows exist only for the adaptive program
TRACE=(); [ "$IMPL" == "naive" ] || TRACE=(--trace-out results/E2_trace.csv)

# ---- E1/E2: correctness + main performance, default configuration ------------------------------
if want E2; then
    for g in $MAIN_GRAPHS; do
        run --graph data/csr/$g.csr --category "$(cat_of $g)" --impl "$IMPL" --sources $SRC --trials $TRIALS \
            --structural --tag E2_main --out results/E2_main.csv "${TRACE[@]}"
    done
fi

# ---- E3: ablation of adaptive-scheme components (adaptive only; naive is in E2) ------------------
if want E3 && [ "$IMPL" != "naive" ]; then
    for g in roadNet-CA soc-LiveJournal1 rmat22; do
        c=$(cat_of $g)
        B="--graph data/csr/$g.csr --category $c --impl adaptive --sources $SRC"
        B="$B --trials $TRIALS --out results/E3_ablation.csv"
        run $B --tag E3_default
        run $B --tag E3_no_block_bucket --no-block-bucket
        run $B --tag E3_no_streams --no-streams
        run $B --tag E3_fused --bucket-mode fused
        for w in 8 16 32 64 128; do for b in 512 1024 2048 4096; do
            run $B --tag E3_thresh --warp-thresh $w --block-thresh $b
        done; done
    done
fi

# ---- E4: strong scaling (fixed graph, grid capped at R blocks per kernel) ----------
if want E4; then
    for g in $SCALE_GRAPHS; do
        for R in 1 2 4 8 16 32 64 128 256 512 1024 0; do
            run --graph data/csr/$g.csr --category "$(cat_of $g)" --impl "$IMPL" --sources 3 \
                --trials 3 --serial-trials 1 --max-blocks $R --tag E4_strong \
                --out results/E4_strong.csv
        done
    done
fi

# ---- E5: weak scaling (graph doubles with resources): scale 15+i, R = 8*2^i ------
if want E5; then
    for i in 0 1 2 3 4 5 6 7; do
        s=$((15+i)); R=$((8*(1<<i)))
        run --graph data/csr/rmat$s.csr --category rmat --impl "$IMPL" --sources 3 \
            --trials 3 --serial-trials 1 --max-blocks $R --tag E5_weak \
            --out results/E5_weak.csv
    done
fi

# ---- E6: block-size sweep (grid unlimited) ---------------------------------------
if want E6; then
    for g in $SCALE_GRAPHS; do
        for B in 32 64 128 256 512 1024; do
            run --graph data/csr/$g.csr --category "$(cat_of $g)" --impl "$IMPL" --sources 3 \
                --trials 3 --serial-trials 1 --block $B --tag E6_block \
                --out results/E6_block.csv
        done
    done
fi
echo "finished. Next: python3 scripts/analyze.py"
