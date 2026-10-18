#!/usr/bin/env bash
# scripts/omp_scaling.sh -- OWNER: Member 1. Measures how host-side OpenMP preprocessing scales with threads.
# Usage: bash scripts/omp_scaling.sh data/raw/com-youtube.ungraph.txt > results/omp_scaling.csv
IN="$1"
# untimed warm-up: the first read of the file comes from disk, which would inflate the 1-thread time
./bin/graph_tool convert "$IN" /tmp/_omp.csr > /dev/null
echo "threads,convert_ms,rmat20_ms"
for t in 1 2 4 8 16; do
    [ "$t" -le "$(nproc)" ] || continue
    c=$(OMP_NUM_THREADS=$t ./bin/graph_tool convert "$IN" /tmp/_omp.csr | awk '/parsed/{print $3}')
    r=$(OMP_NUM_THREADS=$t ./bin/graph_tool rmat 20 16 1 /tmp/_omp_r.csr | awk '/generated/{print $3}')
    echo "$t,$c,$r"
done
