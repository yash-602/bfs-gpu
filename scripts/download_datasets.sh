#!/usr/bin/env bash
# scripts/download_datasets.sh -- OWNER: Member 1.
# Downloads the SNAP graphs into data/raw (text, uncompressed).
# Run from the repository root: bash scripts/download_datasets.sh
set -euo pipefail
mkdir -p data/raw
cd data/raw

get() {  # get <url> : download (resumable) + gunzip, skipping files that already exist
    local url="$1"; local gz; gz="$(basename "$url")"; local txt="${gz%.gz}"
    if [ -f "$txt" ]; then echo "[skip] $txt already present"; return; fi
    echo "[download] $url"
    wget -c --tries=5 "$url"
    gunzip -f "$gz"
}

SNAP=https://snap.stanford.edu/data
get $SNAP/roadNet-CA.txt.gz                               # road network (uniform degree)
get $SNAP/roadNet-PA.txt.gz                               # optional second road network
get $SNAP/bigdata/communities/com-youtube.ungraph.txt.gz  # small social graph
get $SNAP/soc-LiveJournal1.txt.gz                         # social (power law)
get $SNAP/bigdata/communities/com-orkut.ungraph.txt.gz    # social, 117M edges
echo "done. Next: bash scripts/convert_all.sh"
