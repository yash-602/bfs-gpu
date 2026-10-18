// tests/hello_cuda.cu -- shared toolchain check (anyone can run it). Build:
//   nvcc -O2 -std=c++17 -arch=native -Iinclude tests/hello_cuda.cu -o /tmp/hello
// Expected output: GPU info line, then "hello_cuda: PASS"
#include <cstdio>
#include <vector>
#include "cuda_utils.cuh"

__global__ void add_one(int* x, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] += 1;
}

int main() {
    print_gpu_info();
    const int n = 1 << 20;
    std::vector<int> h(n, 41);
    int* d = nullptr;
    CUDA_CHECK(cudaMalloc(&d, n * sizeof(int)));
    CUDA_CHECK(cudaMemcpy(d, h.data(), n * sizeof(int), cudaMemcpyHostToDevice));
    add_one<<<(n + 255) / 256, 256>>>(d, n);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaMemcpy(h.data(), d, n * sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaFree(d));
    for (int i = 0; i < n; ++i)
        if (h[i] != 42) {
            printf("hello_cuda: FAIL at %d\n", i);
            return 1;
        }
    printf("hello_cuda: PASS\n");
    return 0;
}
