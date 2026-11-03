// tests/test_adaptive.cu -- OWNER: Member 3
// GPU correctness test for the adaptive implementation.

#include "test_suite.h"

int main() {
    print_gpu_info();

    bool ok = true;
    int configs = 0;

    for (int mode = 0; mode < 2; ++mode) {
        for (int streams = 0; streams < 2; ++streams) {
            for (int blockb = 0; blockb < 2; ++blockb) {
                for (int tiny = 0; tiny < 2; ++tiny) {
                    for (int bs : {64, 256}) {
                        AdaptiveConfig cfg;
                        cfg.bucket_mode = mode ? BUCKET_FUSED : BUCKET_SCAN;
                        cfg.enable_streams = streams;
                        cfg.enable_block_bucket = blockb;
                        cfg.block_size = bs;

                        if (tiny) {
                            cfg.warp_thresh = 3;
                            cfg.block_thresh = 12;
                        }

                        std::string name =
                            std::string("adaptive mode=") +
                            (mode ? "fused" : "scan") +
                            " streams=" + std::to_string(streams) +
                            " blockbucket=" + std::to_string(blockb) +
                            " tiny=" + std::to_string(tiny) +
                            " bs=" + std::to_string(bs);

                        ok &= run_correctness_suite(
                            name,
                            [&](const DeviceGraph& g, vid_t s,
                                std::vector<int>& lv) {
                                BFSStats st;
                                bfs_adaptive_cuda(g, s, lv, cfg, st);
                            });

                        ++configs;
                    }
                }
            }
        }
    }

    // Grid-cap configurations exercise the strong-scaling code path.
    for (int cap : {1, 2, 5}) {
        AdaptiveConfig cfg;
        cfg.max_blocks = cap;
        cfg.warp_thresh = 3;
        cfg.block_thresh = 12;

        ok &= run_correctness_suite(
            "adaptive cap=" + std::to_string(cap),
            [&](const DeviceGraph& g, vid_t s, std::vector<int>& lv) {
                BFSStats st;
                bfs_adaptive_cuda(g, s, lv, cfg, st);
            });

        ++configs;
    }

    printf("\n%d configurations tested\n", configs);
    printf(ok ? "TEST_ADAPTIVE: PASS\n" : "TEST_ADAPTIVE: FAIL\n");
    return ok ? 0 : 1;
}
