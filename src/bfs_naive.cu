
 // src/bfs_naive.cu -- OWNER: Member 2
 // Naive GPU BFS: frontier queue, ONE THREAD PER FRONTIER VERTEX,
 // static mapping, no degree awareness.

#include <algorithm>
#include <vector>
#include "bfs_api.h"
#include "bfs_device_common.cuh"
#include "cuda_utils.cuh"
#include "timer.h"

__global__ void naive_expand_kernel(
    const eid_t* __restrict__ row_offsets,
    const vid_t* __restrict__ col_indices,
    const vid_t* __restrict__ frontier, int fsize, int* levels,
    int next_level, vid_t* next_frontier, int* next_count) {
    const int stride = gridDim.x * blockDim.x;

    for (int i = blockIdx.x * blockDim.x + threadIdx.x;
         i < fsize; i += stride) {
        const vid_t u = frontier[i];
        const eid_t beg = row_offsets[u], end = row_offsets[u + 1];
        for (eid_t e = beg; e < end; ++e)
            claim_and_push(levels, col_indices[e], next_level,
                           next_frontier, next_count);
    }
}

void bfs_naive_cuda(const DeviceGraph& g, vid_t src,
                    std::vector<int>& h_levels, const NaiveConfig& cfg,
                    BFSStats& stats) {
    const int n = g.n;
    int* d_levels = nullptr;
    int* d_next_n = nullptr;
    vid_t* d_front = nullptr;
    vid_t* d_next = nullptr;

    CUDA_CHECK(cudaMalloc(&d_levels, (size_t)n * sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_next_n, sizeof(int)));
    CUDA_CHECK(cudaMalloc(&d_front, (size_t)n * sizeof(vid_t)));
    CUDA_CHECK(cudaMalloc(&d_next, (size_t)n * sizeof(vid_t)));

    // Setup (not timed)
    CUDA_CHECK(cudaMemset(d_levels, 0xFF, (size_t)n * sizeof(int)));
    const int zero = 0;
    CUDA_CHECK(cudaMemcpy(d_levels + src, &zero, sizeof(int),
                          cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_front, &src, sizeof(vid_t),
                          cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaDeviceSynchronize());

    // Traversal (timed)
    int fsize = 1, level = 0, rounds = 0;
    WallTimer timer;

    while (fsize > 0) {
        CUDA_CHECK(cudaMemset(d_next_n, 0, sizeof(int)));
        int blocks = (fsize + cfg.block_size - 1) / cfg.block_size;
        if (cfg.max_blocks > 0)
            blocks = std::min(blocks, cfg.max_blocks);

        naive_expand_kernel<<<blocks, cfg.block_size>>>(
            g.row_offsets, g.col_indices, d_front, fsize, d_levels,
            level + 1, d_next, d_next_n);
        CUDA_CHECK(cudaGetLastError());

        CUDA_CHECK(cudaMemcpy(&fsize, d_next_n, sizeof(int),
                              cudaMemcpyDeviceToHost));
        std::swap(d_front, d_next);
        ++level;
        ++rounds;
    }

    CUDA_CHECK(cudaDeviceSynchronize());
    stats.kernel_ms = timer.ms();
    stats.iterations = rounds;

    // Teardown (not timed)
    h_levels.resize((size_t)n);
    CUDA_CHECK(cudaMemcpy(h_levels.data(), d_levels,
                          (size_t)n * sizeof(int),
                          cudaMemcpyDeviceToHost));
    cudaFree(d_levels);
    cudaFree(d_next_n);
    cudaFree(d_front);
    cudaFree(d_next);
}
