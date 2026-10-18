// src/graph_stats.cpp -- OWNER: Member 1 (statistics + source selection)
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <numeric>
#include <set>
#include "bfs_api.h"
#include "validate.h"

static inline uint64_t sm64(uint64_t& s) {
    uint64_t z = (s += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

static vid_t max_degree_vertex(const CSRGraph& g) {
    vid_t best = 0;
    for (vid_t v = 1; v < g.n; ++v)
        if (g.degree(v) > g.degree(best)) best = v;
    return best;
}

GraphStats compute_stats(const CSRGraph& g) {
    GraphStats s;
    s.n = g.n;
    s.m = g.m;
    if (g.n == 0) return s;
    s.avg_deg = (double)g.m / g.n;
    s.min_deg = g.degree(0);
    s.max_deg = 0;
    double sq = 0;
    std::vector<long long> degs((size_t)g.n);
    for (vid_t v = 0; v < g.n; ++v) {
        long long d = g.degree(v);
        degs[v] = d;
        s.min_deg = std::min(s.min_deg, d);
        s.max_deg = std::max(s.max_deg, d);
        sq += (double)d * d;
        if (d == 0)
            s.deg0++;
        else {
            int b = 63 - __builtin_clzll((unsigned long long)d);
            if ((int)s.log2_hist.size() <= b) s.log2_hist.resize(b + 1, 0);
            s.log2_hist[b]++;
        }
    }
    double var = sq / g.n - s.avg_deg * s.avg_deg;
    s.std_deg = std::sqrt(std::max(0.0, var));
    s.cv = s.avg_deg > 0 ? s.std_deg / s.avg_deg : 0;

    size_t top = std::max<size_t>(1, (size_t)g.n / 100);
    std::nth_element(degs.begin(), degs.begin() + top, degs.end(), std::greater<long long>());
    long long top_sum = std::accumulate(degs.begin(), degs.begin() + top, 0LL);
    s.top1pct_edge_share = g.m > 0 ? (double)top_sum / g.m : 0;

    // double-sweep diameter lower bound + reachability from the hub
    std::vector<int> lv;
    vid_t hub = max_degree_vertex(g);
    bfs_serial(g, hub, lv);
    long long reached = 0;
    vid_t far = hub;
    int far_lv = 0;
    for (vid_t v = 0; v < g.n; ++v)
        if (lv[v] >= 0) {
            ++reached;
            if (lv[v] > far_lv) {
                far_lv = lv[v];
                far = v;
            }
        }
    s.hub_reach_frac = (double)reached / g.n;
    bfs_serial(g, far, lv);
    int ecc = 0;
    for (vid_t v = 0; v < g.n; ++v) ecc = std::max(ecc, lv[v]);
    s.est_diameter = ecc;
    return s;
}

void print_stats(const CSRGraph& g, const GraphStats& s) {
    printf("graph             : %s\n", g.name.c_str());
    printf("vertices (n)      : %lld\n", s.n);
    printf("CSR entries (m)   : %lld (= 2 x undirected edges)\n", s.m);
    printf("avg degree        : %.3f\n", s.avg_deg);
    printf("std dev degree    : %.3f\n", s.std_deg);
    printf("CV (std/avg)      : %.3f %s\n", s.cv,
           s.cv >= 1.0 ? "-> HIGH-VARIANCE (power-law like)" : "-> low-variance (uniform like)");
    printf("min/max degree    : %lld / %lld\n", s.min_deg, s.max_deg);
    printf("isolated vertices : %lld\n", s.deg0);
    printf("top-1%% edge share : %.1f%%\n", 100.0 * s.top1pct_edge_share);
    printf("est. diameter     : %d (double-sweep lower bound)\n", s.est_diameter);
    printf("reachable from hub: %.2f%% of vertices\n", 100.0 * s.hub_reach_frac);
    printf("degree histogram (vertices with degree in [2^b, 2^(b+1))):\n");
    for (size_t b = 0; b < s.log2_hist.size(); ++b)
        printf("  [%8lld, %8lld) : %lld\n", 1LL << b, 1LL << (b + 1), s.log2_hist[b]);
}

// k source vertices, all with degree>0 and all in the same component as the max-degree vertex.
// Deterministic in seed.
std::vector<vid_t> pick_sources(const CSRGraph& g, int k, uint64_t seed) {
    std::vector<int> lv;
    bfs_serial(g, max_degree_vertex(g), lv);
    std::vector<vid_t> pool;
    for (vid_t v = 0; v < g.n; ++v)
        if (lv[v] >= 0 && g.degree(v) > 0) pool.push_back(v);
    std::vector<vid_t> out;
    if (pool.empty()) {
        out.assign(k, 0);
        return out;
    }
    uint64_t s = seed;
    std::set<vid_t> seen;
    int guard = 0;
    while ((int)out.size() < k) {
        vid_t v = pool[sm64(s) % pool.size()];
        if (seen.count(v) && (int)seen.size() < (int)pool.size() && ++guard < 100000) continue;
        seen.insert(v);
        out.push_back(v);
    }
    return out;
}
