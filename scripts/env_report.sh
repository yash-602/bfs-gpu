#!/usr/bin/env bash
# scripts/env_report.sh -- OWNER: Member 1. Records the hardware/software setup used for a set of results.
# Usage: bash scripts/env_report.sh > results/env.txt
echo "date            : $(date -Iseconds)"
echo "git commit      : $(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
echo "git dirty files : $(git status --porcelain 2>/dev/null | wc -l)"
echo "OS              : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") kernel $(uname -r)"
echo "CPU             : $(lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2}')"
echo "CPU cores       : $(nproc) logical"
echo "RAM             : $(free -h | awk '/Mem:/{print $2}')"
echo "g++             : $(g++ --version | head -1)"
echo "nvcc            : $(nvcc --version 2>/dev/null | tail -1)"
echo "GPU             : $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null)"
echo "GPU clocks      : $(nvidia-smi --query-gpu=clocks.sm,clocks.max.sm --format=csv,noheader 2>/dev/null)"
echo "OMP_NUM_THREADS : ${OMP_NUM_THREADS:-unset (uses all cores)}"
echo "make flags      : ARCH=${ARCH:-native} OPT=${OPT:--O3}"
