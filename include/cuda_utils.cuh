// include/cuda_utils.cuh -- OWNER: Member 1 (frozen contract). Included only from .cu files / GPU
// tests.
#pragma once
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <algorithm>
#include <cuda_runtime.h>
#include "graph.h"

#define CUDA_CHECK(call)                                                                       \
    do {                                                                                       \
        cudaError_t e_ = (call);                                                               \
        if (e_ != cudaSuccess) {                                                               \
            fprintf(stderr, "CUDA error: %s\n  at %s:%d\n  call: %s\n", cudaGetErrorString(e_), \
                    __FILE__, __LINE__, #call);                                                \
            std::exit(EXIT_FAILURE);                                                           \
        }                                                                                      \
    } while (0)

// Copy a host CSR graph to the GPU. Caller must later call free_graph().
inline DeviceGraph upload_graph(const CSRGraph& g) {
    DeviceGraph d;
    d.n = g.n;
    d.m = g.m;
    eid_t* ro = nullptr;
    vid_t* ci = nullptr;
    CUDA_CHECK(cudaMalloc(&ro, (size_t)(g.n + 1) * sizeof(eid_t)));
    CUDA_CHECK(cudaMalloc(&ci, (size_t)std::max<eid_t>(g.m, 1) * sizeof(vid_t)));
    CUDA_CHECK(cudaMemcpy(ro, g.row_offsets.data(), (size_t)(g.n + 1) * sizeof(eid_t),
                          cudaMemcpyHostToDevice));
    if (g.m > 0)
        CUDA_CHECK(
            cudaMemcpy(ci, g.col_indices.data(), (size_t)g.m * sizeof(vid_t), cudaMemcpyHostToDevice));
    d.row_offsets = ro;
    d.col_indices = ci;
    return d;
}

inline void free_graph(DeviceGraph& d) {
    if (d.row_offsets) cudaFree((void*)d.row_offsets);
    if (d.col_indices) cudaFree((void*)d.col_indices);
    d.row_offsets = nullptr;
    d.col_indices = nullptr;
    d.n = 0;
    d.m = 0;
}

inline void print_gpu_info(bool machine_readable = false) {
    int dev = 0;
    CUDA_CHECK(cudaGetDevice(&dev));
    cudaDeviceProp p;
    CUDA_CHECK(cudaGetDeviceProperties(&p, dev));
    int rt = 0, drv = 0;
    cudaRuntimeGetVersion(&rt);
    cudaDriverGetVersion(&drv);
    if (machine_readable) {
        printf(
            "gpu_name=%s\nsm_count=%d\ncompute_capability=%d.%d\nglobal_mem_mb=%zu\n"
            "max_threads_per_sm=%d\nruntime=%d\ndriver=%d\n",
            p.name, p.multiProcessorCount, p.major, p.minor, (size_t)(p.totalGlobalMem >> 20),
            p.maxThreadsPerMultiProcessor, rt, drv);
    } else {
        printf("GPU: %s | SMs: %d | CC %d.%d | %zu MB | CUDA runtime %d | driver %d\n", p.name,
               p.multiProcessorCount, p.major, p.minor, (size_t)(p.totalGlobalMem >> 20), rt, drv);
    }
}
