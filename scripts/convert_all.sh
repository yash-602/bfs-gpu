#!/usr/bin/env bash
# scripts/convert_all.sh -- OWNER: Member 1.
# Converts raw text graphs to binary .csr files and generates RMAT graphs.
# Run from the repository root after 'make host': bash scripts/convert_all.sh
set -euo pipefail
mkdir -p data/csr
T=./bin/graph_tool

conv() {  # conv <raw file> <output name>
    if [ -f "data/csr/$2.csr" ]; then echo "[skip] $2.csr"; return; fi
    if [ ! -f "data/raw/$1" ]; then
        echo "[missing] data/raw/$1 -- run scripts/download_datasets.sh first"; return
    fi
    echo "[convert] $1 -> $2.csr"
    $T convert "data/raw/$1" "data/csr/$2.csr"
}

conv roadNet-CA.txt           roadNet-CA
conv roadNet-PA.txt           roadNet-PA
conv com-youtube.ungraph.txt  com-youtube
conv soc-LiveJournal1.txt     soc-LiveJournal1
conv com-orkut.ungraph.txt    com-orkut

# RMAT graphs, edge factor 16, seed 1 (scales 15..22 are needed for weak scaling)
for s in 15 16 17 18 19 20 21 22; do
    if [ -f "data/csr/rmat$s.csr" ]; then echo "[skip] rmat$s.csr"; continue; fi
    echo "[generate] rmat$s"
    $T rmat $s 16 1 "data/csr/rmat$s.csr"
done
ls -lh data/csr
