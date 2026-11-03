// src/bfs_adaptive.cu -- OWNER: Member 3
// Adaptive load-balanced GPU BFS: classify each frontier by degree into
// LOW / MID / HIGH buckets and expand with thread / warp / block kernels.

#include <climits>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include <cub/cub.cuh>

#include "bfs_api.h"
#include "bfs_device_common.cuh"
#include "cuda_utils.cuh"
#include "timer.h"

struct DegRange {
    const eid_t* ro;
    int lo, hi;

    __host__ __device__ __forceinline__
    bool operator()(const vid_t& v) const {
        const int d = ro[v + 1] - ro[v];
        return d >= lo && d < hi;
    }
};

// LOW: one thread per frontier vertex. Inner loop matches naive BFS.
__global__ void expand_thread_kernel(
    const eid_t* __restrict__ ro, const vid_t* __restrict__ ci,
    const vid_t* __restrict__ q, int qn, int* levels, int next_level,
    vid_t* out, int* out_n) {

    const int stride = gridDim.x * blockDim.x;
    for (int i = blockIdx.x * blockDim.x + threadIdx.x;
         i < qn; i += stride) {
        const vid_t u = q[i];
        const eid_t beg = ro[u], end = ro[u + 1];
        for (eid_t e = beg; e < end; ++e)
            claim_and_push(levels, ci[e], next_level, out, out_n);
    }
}

// MID: one warp per vertex; lanes stride through its adjacency list.
__global__ void expand_warp_kernel(
    const eid_t* __restrict__ ro, const vid_t* __restrict__ ci,
    const vid_t* __restrict__ q, int qn, int* levels, int next_level,
    vid_t* out, int* out_n) {

    const int lane = threadIdx.x & (WARP_SZ - 1);
    const int warp_global =
        (blockIdx.x * blockDim.x + threadIdx.x) >> 5;
    const int warps_total = (gridDim.x * blockDim.x) >> 5;

    for (int i = warp_global; i < qn; i += warps_total) {
        const vid_t u = q[i];
        const eid_t beg = ro[u], end = ro[u + 1];
        for (eid_t e = beg + lane; e < end; e += WARP_SZ)
            claim_and_push(levels, ci[e], next_level, out, out_n);
    }
}

// HIGH: one CUDA block per vertex; threads stride through its adjacency list.
__global__ void expand_block_kernel(
    const eid_t* __restrict__ ro, const vid_t* __restrict__ ci,
    const vid_t* __restrict__ q, int qn, int* levels, int next_level,
    vid_t* out, int* out_n) {

    for (int i = blockIdx.x; i < qn; i += gridDim.x) {
        const vid_t u = q[i];
        const eid_t beg = ro[u], end = ro[u + 1];
        for (eid_t e = beg + threadIdx.x; e < end; e += blockDim.x)
            claim_and_push(levels, ci[e], next_level, out, out_n);
    }
}

// FUSED: classify in one pass; expand LOW immediately and queue MID/HIGH.
__global__ void fused_classify_expand_kernel(
    const eid_t* __restrict__ ro, const vid_t* __restrict__ ci,
    const vid_t* __restrict__ front, int fsize, int* levels,
    int next_level, vid_t* out, int* out_n, vid_t* q_mid,
    int* n_mid, vid_t* q_high, int* n_high, int t1, int t2) {

    const int stride = gridDim.x * blockDim.x;
    for (int i = blockIdx.x * blockDim.x + threadIdx.x;
         i < fsize; i += stride) {
        const vid_t u = front[i];
        const eid_t beg = ro[u], end = ro[u + 1];
        const int d = end - beg;

        if (d < t1) {
            for (eid_t e = beg; e < end; ++e)
                claim_and_push(levels, ci[e], next_level, out, out_n);
        } else if (d < t2) {
            append_coalesced(q_mid, n_mid, u);
        } else {
            append_coalesced(q_high, n_high, u);
        }
    }
}

static inline int grid_for(long long blocks_needed, int cap) {
    long long b = std::max<long long>(
        1, std::min<long long>(blocks_needed, INT_MAX));
    if (cap > 0)
        b = std::min<long long>(b, cap);
    return static_cast<int>(b);
}

void bfs_adaptive_cuda(
    const DeviceGraph& g, vid_t src, std::vector<int>& h_levels,
    const AdaptiveConfig& cfg, BFSStats& stats) {

    const int n = g.n;
    const int bs = cfg.block_size;

    if (bs < 32 || bs > 1024 || (bs % 32) != 0) {
        fprintf(stderr, "block_size must be a multiple of 32 in [32,1024]\n");
        exit(1);
    }

    const int t1 = cfg.warp_thresh;
    const bool hb = cfg.enable_block_bucket;
    const int t2 = hb ? cfg.block_thresh : INT_MAX;

    if (t1 < 0 || (hb && t2 <= t1)) {
        fprintf(stderr, "invalid adaptive degree thresholds\n");
        exit(1);
    }

    // Allocate device buffers (not included in traversal timing).
    int *d_levels = nullptr, *d_next_n = nullptr, *d_counts = nullptr;
    vid_t *d_front = nullptr, *d_next = nullptr;
    vid_t* d_q[3] = {nullptr, nullptr, nullptr};

    CUDA_CHECK(cudaMalloc(&d_levels, (size_t)n * sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_next_n, sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_counts, 4 * sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_front, (size_t)n * sizeof(vid_t)));
    CUDA_CHECK(cudaMalloc(&d_next, (size_t)n * sizeof(vid_t)));

    for (int i = 0; i < 3; ++i)
        CUDA_CHECK(cudaMalloc(&d_q[i], (size_t)n * sizeof(vid_t)));

    int* h_counts = nullptr;
    CUDA_CHECK(cudaMallocHost((void**)&h_counts, 4 * sizeof(int)));

    // CUB scratch space is sized once and reused at every BFS level.
    void* d_temp = nullptr;
    size_t temp_bytes = 0;

    if (cfg.bucket_mode == BUCKET_SCAN) {
        DegRange probe{g.row_offsets, 0, t1};
        CUDA_CHECK(cub::DeviceSelect::If(
            nullptr, temp_bytes, d_front, d_q[0], d_counts, n, probe));
        CUDA_CHECK(cudaMalloc(&d_temp, std::max<size_t>(temp_bytes, 1)));
    }

    // Main stream handles classification/copies. Three optional streams
    // handle LOW, MID and HIGH expansion independently.
    cudaStream_t s_main, s_k[3];
    CUDA_CHECK(cudaStreamCreateWithFlags(&s_main, cudaStreamNonBlocking));
    for (int i = 0; i < 3; ++i)
        CUDA_CHECK(cudaStreamCreateWithFlags(&s_k[i], cudaStreamNonBlocking));

    cudaStream_t st_low = cfg.enable_streams ? s_k[0] : s_main;
    cudaStream_t st_mid = cfg.enable_streams ? s_k[1] : s_main;
    cudaStream_t st_high = cfg.enable_streams ? s_k[2] : s_main;

    CUDA_CHECK(cudaMemset(d_levels, 0xFF, (size_t)n * sizeof(int)));
    const int zero = 0;
    CUDA_CHECK(cudaMemcpy(
        d_levels + src, &zero, sizeof(int), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(
        d_front, &src, sizeof(vid_t), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaDeviceSynchronize());

    // BFS traversal (timed).
    stats.trace.clear();
    int fsize = 1, level = 0, rounds = 0;
    WallTimer total;

    while (fsize > 0) {
        WallTimer lvl_timer;
        const int cur = fsize;
        int nl = 0, nm = 0, nh = 0;

        CUDA_CHECK(cudaMemsetAsync(d_next_n, 0, sizeof(int), s_main));

        // 1. Classify frontier vertices into degree buckets.
        if (cfg.bucket_mode == BUCKET_SCAN) {
            DegRange p_low{g.row_offsets, 0, t1};
            DegRange p_mid{g.row_offsets, t1, t2};
            DegRange p_high{g.row_offsets, t2, INT_MAX};

            size_t tb = temp_bytes;
            CUDA_CHECK(cub::DeviceSelect::If(
                d_temp, tb, d_front, d_q[0], d_counts + 0,
                fsize, p_low, s_main));
            CUDA_CHECK(cub::DeviceSelect::If(
                d_temp, tb, d_front, d_q[1], d_counts + 1,
                fsize, p_mid, s_main));

            if (hb) {
                CUDA_CHECK(cub::DeviceSelect::If(
                    d_temp, tb, d_front, d_q[2], d_counts + 2,
                    fsize, p_high, s_main));
            } else {
                CUDA_CHECK(cudaMemsetAsync(
                    d_counts + 2, 0, sizeof(int), s_main));
            }

            CUDA_CHECK(cudaMemcpyAsync(
                h_counts, d_counts, 3 * sizeof(int),
                cudaMemcpyDeviceToHost, s_main));
            CUDA_CHECK(cudaStreamSynchronize(s_main));

            nl = h_counts[0];
            nm = h_counts[1];
            nh = h_counts[2];
        } else {
            // FUSED: LOW expands immediately; MID/HIGH are queued.
            CUDA_CHECK(cudaMemsetAsync(
                d_counts, 0, 3 * sizeof(int), s_main));

            fused_classify_expand_kernel
                <<<grid_for((fsize + bs - 1) / bs, cfg.max_blocks),
                   bs, 0, s_main>>>(
                    g.row_offsets, g.col_indices, d_front, fsize,
                    d_levels, level + 1, d_next, d_next_n,
                    d_q[1], d_counts + 1, d_q[2], d_counts + 2,
                    t1, t2);
            CUDA_CHECK(cudaGetLastError());

            CUDA_CHECK(cudaMemcpyAsync(
                h_counts, d_counts, 3 * sizeof(int),
                cudaMemcpyDeviceToHost, s_main));
            CUDA_CHECK(cudaStreamSynchronize(s_main));

            nm = h_counts[1];
            nh = h_counts[2];
            nl = fsize - nm - nh;
        }

        // 2. Launch the appropriate expansion kernel for each nonempty bucket.
        if (cfg.bucket_mode == BUCKET_SCAN && nl > 0) {
            expand_thread_kernel
                <<<grid_for((nl + bs - 1) / bs, cfg.max_blocks),
                   bs, 0, st_low>>>(
                    g.row_offsets, g.col_indices, d_q[0], nl,
                    d_levels, level + 1, d_next, d_next_n);
        }

        if (nm > 0) {
            expand_warp_kernel
                <<<grid_for(((long long)nm * WARP_SZ + bs - 1) / bs,
                            cfg.max_blocks),
                   bs, 0, st_mid>>>(
                    g.row_offsets, g.col_indices, d_q[1], nm,
                    d_levels, level + 1, d_next, d_next_n);
        }

        if (nh > 0) {
            expand_block_kernel
                <<<grid_for(nh, cfg.max_blocks), bs, 0, st_high>>>(
                    g.row_offsets, g.col_indices, d_q[2], nh,
                    d_levels, level + 1, d_next, d_next_n);
        }

        CUDA_CHECK(cudaGetLastError());

        // 3. Wait for all work before advancing to the next BFS level.
        CUDA_CHECK(cudaStreamSynchronize(s_main));
        for (int i = 0; i < 3; ++i)
            CUDA_CHECK(cudaStreamSynchronize(s_k[i]));

        CUDA_CHECK(cudaMemcpy(
            &fsize, d_next_n, sizeof(int), cudaMemcpyDeviceToHost));

        if (cfg.trace) {
            LevelTrace t;
            t.level = level;
            t.frontier = cur;
            t.n_low = nl;
            t.n_mid = nm;
            t.n_high = nh;
            t.ms = lvl_timer.ms();
            stats.trace.push_back(t);
        }

        std::swap(d_front, d_next);
        ++level;
        ++rounds;
    }

    CUDA_CHECK(cudaDeviceSynchronize());
    stats.kernel_ms = total.ms();
    stats.iterations = rounds;

    // Copy final BFS levels back to the host.
    h_levels.resize((size_t)n);
    CUDA_CHECK(cudaMemcpy(
        h_levels.data(), d_levels, (size_t)n * sizeof(int),
        cudaMemcpyDeviceToHost));

    // Release all resources.
    for (int i = 0; i < 3; ++i)
        CUDA_CHECK(cudaStreamDestroy(s_k[i]));
    CUDA_CHECK(cudaStreamDestroy(s_main));

    CUDA_CHECK(cudaFree(d_levels));
    CUDA_CHECK(cudaFree(d_next_n));
    CUDA_CHECK(cudaFree(d_counts));
    CUDA_CHECK(cudaFree(d_front));
    CUDA_CHECK(cudaFree(d_next));

    for (int i = 0; i < 3; ++i)
        CUDA_CHECK(cudaFree(d_q[i]));

    if (d_temp)
        CUDA_CHECK(cudaFree(d_temp));

    CUDA_CHECK(cudaFreeHost(h_counts));
}
