// src/graph_gen.cpp -- OWNER: Member 1
#include <omp.h>
#include <algorithm>
#include "graph.h"

static inline uint64_t splitmix64(uint64_t& s) {
    uint64_t z = (s += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}
static inline double uniform01(uint64_t& s) {
    return (splitmix64(s) >> 11) * (1.0 / 9007199254740992.0);
}

static CSRGraph finish(vid_t n, std::vector<Edge>& e, const char* name) {
    CSRGraph g;
    build_csr_from_edges(n, e, g);
    g.name = name;
    return g;
}

CSRGraph make_path(int n) {
    std::vector<Edge> e;
    for (int i = 0; i + 1 < n; ++i) e.emplace_back(i, i + 1);
    return finish(n, e, "path");
}
CSRGraph make_star(int n) {
    std::vector<Edge> e;
    for (int i = 1; i < n; ++i) e.emplace_back(0, i);
    return finish(n, e, "star");
}
CSRGraph make_grid(int w, int h) {
    std::vector<Edge> e;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            int v = y * w + x;
            if (x + 1 < w) e.emplace_back(v, v + 1);
            if (y + 1 < h) e.emplace_back(v, v + w);
        }
    return finish(w * h, e, "grid");
}
CSRGraph make_random(int n, int avg_deg, uint64_t seed) {
    std::vector<Edge> e;
    uint64_t s = seed;
    long long m = (long long)n * avg_deg / 2;
    for (long long i = 0; i < m; ++i)
        e.emplace_back((vid_t)(splitmix64(s) % (uint64_t)n), (vid_t)(splitmix64(s) % (uint64_t)n));
    return finish(n, e, "random");
}
CSRGraph make_two_components(int n1, int n2) {
    std::vector<Edge> e;
    for (int i = 0; i + 1 < n1; ++i) e.emplace_back(i, i + 1);
    for (int i = 0; i + 1 < n2; ++i) e.emplace_back(n1 + i, n1 + i + 1);
    return finish(n1 + n2, e, "two_components");
}
// vertex 0 = hub with `hub_deg` leaves (1..hub_deg); leaf 1 continues into a path of `path_len` more
// vertices
CSRGraph make_hub_and_path(int hub_deg, int path_len) {
    std::vector<Edge> e;
    for (int i = 1; i <= hub_deg; ++i) e.emplace_back(0, i);
    int prev = 1;
    for (int i = 0; i < path_len; ++i) {
        int v = hub_deg + 1 + i;
        e.emplace_back(prev, v);
        prev = v;
    }
    return finish(hub_deg + 1 + path_len, e, "hub_and_path");
}

// Graph500-style R-MAT: probabilities A=0.57 B=0.19 C=0.19 D=0.05. Deterministic for a given
// (scale, edge_factor, seed) regardless of thread count (each 65536-edge block has its own RNG stream).
CSRGraph make_rmat(int scale, int edge_factor, uint64_t seed, bool scramble) {
    const double A = 0.57, B = 0.19, C = 0.19;
    const vid_t n = (vid_t)1 << scale;
    const long long M = (long long)edge_factor * n;
    const uint64_t mask = ((uint64_t)1 << scale) - 1;
    std::vector<Edge> e((size_t)M);
    const long long BLK = 1 << 16;
    const long long nblk = (M + BLK - 1) / BLK;
#pragma omp parallel for schedule(static)
    for (long long b = 0; b < nblk; ++b) {
        // Mix (seed, block) through the splitmix finalizer so that different blocks start at unrelated
        // positions of the generator cycle (seeding with seed+b would make blocks overlap ->
        // duplicates).
        uint64_t t = seed ^ ((uint64_t)(b + 1) * 0xD1B54A32D192ED03ULL);
        uint64_t s = splitmix64(t);
        long long lo = b * BLK, hi = std::min(M, lo + BLK);
        for (long long i = lo; i < hi; ++i) {
            uint64_t u = 0, v = 0;
            for (int lvl = 0; lvl < scale; ++lvl) {
                double r = uniform01(s);
                if (r < A) {
                } else if (r < A + B)
                    v |= (uint64_t)1 << lvl;
                else if (r < A + B + C)
                    u |= (uint64_t)1 << lvl;
                else {
                    u |= (uint64_t)1 << lvl;
                    v |= (uint64_t)1 << lvl;
                }
            }
            if (scramble) {  // three bijections on [0, 2^scale): hides the locality R-MAT puts in low
                             // ids
                auto perm = [&](uint64_t x) {
                    x = (x * 0x9E3779B1ULL + 0x7F4A7C15ULL) & mask;
                    x ^= x >> (scale / 2 + 1);
                    x = (x * 0x85EBCA6BULL) & mask;
                    return x;
                };
                u = perm(u);
                v = perm(v);
            }
            e[i] = Edge((vid_t)u, (vid_t)v);
        }
    }
    CSRGraph g;
    build_csr_from_edges(n, e, g);
    g.name = "rmat" + std::to_string(scale);
    return g;
}
