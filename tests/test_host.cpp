// tests/test_host.cpp -- OWNER: Member 1. Host-only unit tests (no GPU needed).
#include <cstdio>
#include <cstdlib>
#include <omp.h>
#include <algorithm>
#include "bfs_api.h"
#include "validate.h"

static int g_fail = 0, g_pass = 0;

#define CHECK(cond, msg)                                              \
    do {                                                              \
        if (cond) {                                                   \
            ++g_pass;                                                 \
        } else {                                                      \
            ++g_fail;                                                 \
            printf("  FAIL: %s (%s:%d)\n", msg, __FILE__, __LINE__); \
        }                                                             \
    } while (0)

static bool csr_invariants(const CSRGraph& g) {
    if ((int)g.row_offsets.size() != g.n + 1 || (int)g.col_indices.size() != g.m) return false;
    if (g.row_offsets[0] != 0 || g.row_offsets[g.n] != g.m) return false;
    for (vid_t u = 0; u < g.n; ++u) {
        if (g.row_offsets[u] > g.row_offsets[u + 1]) return false;
        for (eid_t e = g.row_offsets[u]; e < g.row_offsets[u + 1]; ++e) {
            vid_t v = g.col_indices[e];
            if (v < 0 || v >= g.n || v == u) return false;                      // range, no self loop
            if (e > g.row_offsets[u] && g.col_indices[e - 1] >= v) return false;  // sorted + unique
            // symmetry: u must appear in v's list
            const vid_t* b = g.col_indices.data() + g.row_offsets[v];
            const vid_t* en = g.col_indices.data() + g.row_offsets[v + 1];
            if (!std::binary_search(b, en, u)) return false;
        }
    }
    return true;
}

static void test_build() {
    printf("[build_csr_from_edges]\n");
    std::vector<Edge> e = {{0, 1}, {1, 0}, {1, 2},
                           {2, 2}, {0, 1}, {3, 1}};  // dup, reverse dup, self loop
    CSRGraph g;
    CHECK(build_csr_from_edges(5, e, g), "build ok");
    CHECK(g.n == 5, "n");
    CHECK(g.m == 6, "m = 3 undirected edges * 2 (0-1, 1-2, 1-3)");
    CHECK(g.degree(1) == 3 && g.degree(4) == 0, "degrees");
    CHECK(csr_invariants(g), "invariants");
}

static void test_small_graphs() {
    printf("[small generators + serial BFS]\n");
    CSRGraph p = make_path(10);
    CHECK(csr_invariants(p) && p.m == 18, "path invariants");
    std::vector<int> lv;
    bfs_serial(p, 0, lv);
    bool ok = true;
    for (int i = 0; i < 10; ++i) ok &= (lv[i] == i);
    CHECK(ok, "path levels == index");
    bfs_serial(p, 5, lv);
    CHECK(lv[0] == 5 && lv[9] == 4 && lv[5] == 0, "path from middle");

    CSRGraph s = make_star(100);
    CHECK(csr_invariants(s) && s.degree(0) == 99, "star");
    bfs_serial(s, 7, lv);
    CHECK(lv[7] == 0 && lv[0] == 1 && lv[50] == 2, "star from leaf");

    CSRGraph gr = make_grid(5, 4);
    bfs_serial(gr, 0, lv);
    ok = true;
    for (int y = 0; y < 4; ++y)
        for (int x = 0; x < 5; ++x) ok &= (lv[y * 5 + x] == x + y);
    CHECK(csr_invariants(gr) && ok, "grid levels == manhattan distance");

    CSRGraph tc = make_two_components(5, 4);
    bfs_serial(tc, 0, lv);
    CHECK(lv[4] == 4 && lv[5] == -1 && lv[8] == -1, "unreachable stay -1");

    CSRGraph hp = make_hub_and_path(50, 20);
    CHECK(csr_invariants(hp) && hp.degree(0) == 50, "hub_and_path");
    bfs_serial(hp, 0, lv);
    CHECK(lv[1] == 1 && lv[hp.n - 1] == 21, "hub_and_path tail depth");

    CSRGraph one = make_path(1);
    bfs_serial(one, 0, lv);
    CHECK(one.n == 1 && one.m == 0 && lv.size() == 1 && lv[0] == 0, "single vertex");

    CSRGraph r = make_random(2000, 8, 3);
    CHECK(csr_invariants(r), "random invariants");
}

static void test_rmat() {
    printf("[rmat]\n");
    CSRGraph a = make_rmat(12, 16, 42);
    CHECK(csr_invariants(a), "rmat invariants");
    omp_set_num_threads(1);
    CSRGraph b = make_rmat(12, 16, 42);
    omp_set_num_threads(4);
    CSRGraph c = make_rmat(12, 16, 42);
    CHECK(a.row_offsets == b.row_offsets && a.col_indices == b.col_indices,
          "deterministic across thread counts (default vs 1)");
    CHECK(b.row_offsets == c.row_offsets && b.col_indices == c.col_indices,
          "deterministic across thread counts (1 vs 4)");
    CSRGraph d = make_rmat(12, 16, 43);
    CHECK(d.col_indices != a.col_indices, "different seed gives different graph");
    // Regression test for a real bug (overlapping per-block RNG streams made edges collapse into
    // duplicates): with edge factor 16, the average stored degree must be well above 20 and must not
    // shrink with scale.
    CSRGraph s13 = make_rmat(13, 16, 1), s16 = make_rmat(16, 16, 1);
    CHECK((double)s13.m / s13.n > 20.0 && (double)s16.m / s16.n > 20.0, "rmat avg degree > 20");
    CHECK(s16.m > 4 * s13.m, "rmat edge count grows with scale");
    GraphStats st = compute_stats(a);
    CHECK(st.cv > 1.0, "rmat is high-variance (CV > 1)");
    CSRGraph ro = make_grid(64, 64);
    CHECK(compute_stats(ro).cv < 0.5, "grid is low-variance");
}

static void test_validation() {
    printf("[validation]\n");
    CSRGraph g = make_random(5000, 6, 9);
    std::vector<vid_t> src = pick_sources(g, 3, 5);
    CHECK(src.size() == 3, "pick_sources count");
    std::vector<int> ref;
    bfs_serial(g, src[0], ref);
    CHECK(compare_levels(ref, ref).ok, "compare identical");
    CHECK(validate_levels_structural(g, src[0], ref).ok, "structural accepts correct levels");
    std::vector<int> bad = ref;
    vid_t victim = (src[0] + 1) % g.n;
    for (vid_t v = 0; v < g.n; ++v)
        if (ref[v] > 1) {
            victim = v;
            break;
        }
    bad[victim] += 1;
    ValidationResult r = compare_levels(ref, bad);
    CHECK(!r.ok && r.mismatches == 1 && r.first_bad == victim, "compare catches single corruption");
    CHECK(!validate_levels_structural(g, src[0], bad).ok, "structural catches corruption");
    std::vector<int> wrongsrc = ref;
    wrongsrc[src[0]] = 1;
    CHECK(!validate_levels_structural(g, src[0], wrongsrc).ok, "structural catches bad source level");
    long long te = count_traversed_edges(g, ref);
    long long expect = 0;
    for (vid_t v = 0; v < g.n; ++v)
        if (ref[v] >= 0) expect += g.degree(v);
    CHECK(te == expect, "traversed edges");
    CHECK(count_levels(ref) > 1, "levels count");
}

static void test_binary_roundtrip() {
    printf("[binary cache]\n");
    CSRGraph g = make_rmat(10, 8, 5), h;
    CHECK(save_binary(g, "/tmp/_t.csr") && load_binary("/tmp/_t.csr", h), "save/load");
    CHECK(g.n == h.n && g.m == h.m && g.row_offsets == h.row_offsets && g.col_indices == h.col_indices,
          "roundtrip identical");
}

static void test_text_loader() {
    printf("[text loader]\n");
    FILE* f = fopen("/tmp/_t.txt", "w");
    fprintf(f, "# comment line\n# another\n100\t200\n200\t300\r\n300 100\n100 100\n7 300\n\n");
    fclose(f);
    CSRGraph g;
    CHECK(load_edge_list("/tmp/_t.txt", g), "load ok");
    CHECK(g.n == 4, "4 distinct ids compacted");  // 7,100,200,300
    CHECK(g.m == 8, "4 undirected edges: 100-200,200-300,300-100,7-300 (self loop dropped)");
    CHECK(csr_invariants(g), "invariants");
    // many-line file, thread-split boundaries must not lose lines
    f = fopen("/tmp/_big.txt", "w");
    const int N = 200000;
    for (int i = 0; i < N; ++i) fprintf(f, "%d\t%d\n", i, i + 1);
    fclose(f);
    CSRGraph p;
    CHECK(load_edge_list("/tmp/_big.txt", p) && p.n == N + 1 && p.m == 2 * N,
          "big path file parsed exactly (no lost/duplicated lines)");
}

int main() {
    test_build();
    test_small_graphs();
    test_rmat();
    test_validation();
    test_binary_roundtrip();
    test_text_loader();
    printf("\n%d checks passed, %d failed\n", g_pass, g_fail);
    return g_fail ? 1 : 0;
}
