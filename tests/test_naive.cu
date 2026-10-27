
 // tests/test_naive.cu -- OWNER: Member 2. GPU correctness test for the naive implementation.
#include "test_suite.h"

int main() {
    print_gpu_info();
    bool ok = true;
    const int blocks[] = {32, 128, 256, 1024};
    const int caps[] = {0, 1, 3};

    for (int bs : blocks)
        for (int cap : caps) {
            NaiveConfig cfg;
            cfg.block_size = bs;
            cfg.max_blocks = cap;
            std::string name = "naive block=" + std::to_string(bs) +
                               " cap=" + std::to_string(cap);

            ok &= run_correctness_suite(
                name, [&](const DeviceGraph& g, vid_t s, std::vector<int>& lv) {
                    BFSStats st;
                    bfs_naive_cuda(g, s, lv, cfg, st);
                });
        }

    printf(ok ? "\nTEST_NAIVE: PASS\n" : "\nTEST_NAIVE: FAIL\n");
    return ok ? 0 : 1;
}
