#!/usr/bin/env bash
# scripts/check_all.sh -- OWNER: Member 1. One command that proves the whole project builds and is correct.
# Usage (repo root): bash scripts/check_all.sh   -> prints "ALL CHECKS PASSED" or the first failure
set -euo pipefail

# Notice only (not a failure by itself): list teammate files that are still placeholders.
PH=$(grep -rl "PLACEHOLDER-NOT-YET-DELIVERED" src tests scripts docs 2>/dev/null | grep -v check_all.sh || true)
if [ -n "$PH" ]; then
    echo "[0/5] NOTE: these files are still placeholders (GPU checks will fail until replaced):"
    echo "$PH" | sed 's/^/      /'
fi

echo "[1/5] build host tools";   make host
echo "[2/5] host unit tests";    ./bin/test_host
echo "[3/5] build GPU programs"; make gpu
echo "[4/5] naive GPU tests";    ./bin/test_naive | tail -3
echo "[5/5] adaptive GPU tests"; ./bin/test_adaptive | tail -3
./bin/test_naive | grep -q "TEST_NAIVE: PASS"
./bin/test_adaptive | grep -q "TEST_ADAPTIVE: PASS"
echo "ALL CHECKS PASSED"
