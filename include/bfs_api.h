// include/bfs_api.h -- OWNER: Member 1 (frozen contract)
#pragma once
#include <vector>
#include "types.h"
#include "graph.h"

// ----- per-level trace row (filled by the adaptive implementation when cfg.trace == true) -----
struct LevelTrace {
    int level = 0;                         // BFS level being expanded (0 = source)
    int frontier = 0;                      // frontier size at that level
    int n_low = 0, n_mid = 0, n_high = 0;  // bucket sizes (adaptive only)
    double ms = 0.0;                       // wall time of this level
};

struct BFSStats {
    double kernel_ms = 0.0;  // traversal time: see "Timing definition" in the contract
    int iterations = 0;      // number of expansion rounds executed
    std::vector<LevelTrace> trace;
};

// ----- naive (Member 2) -----
struct NaiveConfig {
    int block_size = 256;  // threads per block, multiple of 32
    int max_blocks = 0;    // 0 = unlimited (grid = ceil(frontier/block_size)); >0 caps the grid
};
// h_levels is resized to g.n and filled with BFS levels (UNVISITED = -1).
void bfs_naive_cuda(const DeviceGraph& g, vid_t src, std::vector<int>& h_levels, const NaiveConfig& cfg,
                    BFSStats& stats);

// ----- adaptive (Member 3) -----
enum BucketMode { BUCKET_SCAN = 0, BUCKET_FUSED = 1 };

struct AdaptiveConfig {
    int block_size = 256;             // threads per block, multiple of 32
    int max_blocks = 0;               // per-kernel grid cap, 0 = unlimited
    int warp_thresh = 32;             // degree < warp_thresh                 -> thread-per-vertex
    int block_thresh = 1024;          // warp_thresh <= degree < block_thresh -> warp-per-vertex
                                      // degree >= block_thresh               -> block-per-vertex
    bool enable_block_bucket = true;  // false: everything >= warp_thresh goes to the warp kernel
    bool enable_streams = true;       // false: run the three expansion kernels on one stream
    BucketMode bucket_mode = BUCKET_SCAN;
    bool trace = false;  // fill stats.trace (adds overhead; never use for timed runs)
};

void bfs_adaptive_cuda(const DeviceGraph& g, vid_t src, std::vector<int>& h_levels,
                       const AdaptiveConfig& cfg, BFSStats& stats);

// ----- serial reference (Member 1) -----
void bfs_serial(const CSRGraph& g, vid_t src, std::vector<int>& levels);
