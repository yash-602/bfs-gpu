// include/test_suite.h -- OWNER: Member 1 (frozen contract). Included only from GPU test programs
// (.cu).
#pragma once
#include <cstdio>
#include <functional>
#include <string>
#include <vector>
#include "bfs_api.h"
#include "cuda_utils.cuh"
#include "graph.h"
#include "validate.h"

// A BFS implementation under test: given a device graph and a source, fill `levels`.
typedef std::function<void(const DeviceGraph&, vid_t, std::vector<int>&)> BfsRunFn;

// Runs `fn` on a fixed suite of small graphs (several sources each) and compares every result with the
// serial reference AND with the structural validator. Prints one line per graph. Returns true if all
// pass.
inline bool run_correctness_suite(const std::string& impl_name, const BfsRunFn& fn) {
    std::vector<CSRGraph> suite;
    suite.push_back(make_path(1));  // single vertex
    suite.push_back(make_path(2));
    suite.push_back(make_path(1000));                // 999 levels, tiny frontiers
    suite.push_back(make_star(5000));                // one giant hub
    suite.push_back(make_grid(64, 64));              // uniform degree 2..4
    suite.push_back(make_random(20000, 8, 1));       // medium degrees
    suite.push_back(make_two_components(500, 300));  // unreachable vertices stay -1
    suite.push_back(make_hub_and_path(3000, 400));   // hub + very long tail
    suite.push_back(make_rmat(12, 16, 7));           // power law
    suite.push_back(make_rmat(15, 16, 8));           // bigger power law

    bool all_ok = true;
    printf("=== correctness suite: %s ===\n", impl_name.c_str());
    for (const CSRGraph& g : suite) {
        DeviceGraph dg = upload_graph(g);
        std::vector<vid_t> srcs = {0, (vid_t)(g.n / 2), (vid_t)(g.n - 1)};
        std::vector<vid_t> extra = pick_sources(g, 3, 11);
        srcs.insert(srcs.end(), extra.begin(), extra.end());
        int ok_count = 0;
        std::string first_msg;
        for (vid_t s : srcs) {
            std::vector<int> ref, got;
            bfs_serial(g, s, ref);
            fn(dg, s, got);
            ValidationResult a = compare_levels(ref, got);
            ValidationResult b = validate_levels_structural(g, s, got);
            if (a.ok && b.ok)
                ++ok_count;
            else if (first_msg.empty())
                first_msg = "src " + std::to_string(s) + ": " + (a.ok ? b.msg : a.msg);
        }
        bool ok = (ok_count == (int)srcs.size());
        all_ok &= ok;
        printf("  %-16s n=%-8d m=%-9d %d/%d sources %s %s\n", g.name.c_str(), g.n, g.m, ok_count,
               (int)srcs.size(), ok ? "PASS" : "FAIL", first_msg.c_str());
        free_graph(dg);
    }
    printf("=== %s: %s ===\n", impl_name.c_str(), all_ok ? "ALL PASS" : "FAILURES");
    return all_ok;
}
