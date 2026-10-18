// include/bfs_device_common.cuh -- OWNER: Member 1 (frozen contract). Used by Member 2 AND Member 3.
#pragma once
#include <cuda_runtime.h>
#include <cooperative_groups.h>
#include "types.h"
namespace cg = cooperative_groups;

// Append v to queue `out` using ONE atomicAdd per group of currently-converged threads
// (warp-aggregated append). Must be called from inside a branch that only the appending threads enter.
__device__ __forceinline__ void append_coalesced(vid_t* out, int* out_n, vid_t v) {
    cg::coalesced_group g = cg::coalesced_threads();
    int base = 0;
    if (g.thread_rank() == 0) base = atomicAdd(out_n, (int)g.size());
    base = g.shfl(base, 0);
    out[base + g.thread_rank()] = v;
}

// Try to claim vertex v for `next_level`. Exactly one thread wins per vertex; the winner appends v to
// the next frontier.
__device__ __forceinline__ void claim_and_push(int* levels, vid_t v, int next_level, vid_t* out,
                                               int* out_n) {
    bool won = false;
    if (levels[v] == UNVISITED)  // cheap non-atomic pre-check
        won = (atomicCAS(&levels[v], UNVISITED, next_level) == UNVISITED);
    if (won) append_coalesced(out, out_n, v);
}
