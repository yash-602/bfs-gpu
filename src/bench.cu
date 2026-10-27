// src/bench.cu -- OWNER: Member 2. Benchmark driver: serial reference, naive, adaptive; verification;
// CSV logging.
#include <sys/stat.h>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>
#include "bfs_api.h"
#include "cuda_utils.cuh"
#include "graph.h"
#include "timer.h"
#include "validate.h"

// ------------------------------------------------------------------ options
struct Options {
    std::string graph, category = "unknown", impl = "both", out = "results/results.csv", tag = "adhoc",
                       trace_out;
    int rmat_scale = -1, rmat_ef = 16;
    int sources = 5, trials = 5, warmup = 1, serial_trials = 3;
    uint64_t seed = 1;
    bool structural = false, gpu_info = false;
    NaiveConfig nc;
    AdaptiveConfig ac;
};

static void usage() {
    fprintf(stderr,
            "bench options:\n"
            "  --graph FILE | --rmat-scale S [--rmat-ef 16]   graph input (.csr binary or SNAP text) "
            "or generated RMAT\n"
            "  --category road|social|rmat|other              label written to the CSV\n"
            "  --impl serial|naive|adaptive|both              (default both; serial reference always "
            "runs)\n"
            "  --sources K --trials T --warmup W --serial-trials S --seed N\n"
            "  --block B --max-blocks R                       grid config (applies to naive AND "
            "adaptive)\n"
            "  --warp-thresh A --block-thresh B --bucket-mode scan|fused --no-streams "
            "--no-block-bucket (adaptive only)\n"
            "  --out FILE --tag LABEL --trace-out FILE --structural --gpu-info\n");
}

static bool parse(int argc, char** argv, Options& o) {
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto need = [&](const char* name) -> const char* {
            if (i + 1 >= argc) {
                fprintf(stderr, "missing value for %s\n", name);
                exit(1);
            }
            return argv[++i];
        };
        if (a == "--graph")
            o.graph = need("--graph");
        else if (a == "--rmat-scale")
            o.rmat_scale = atoi(need("--rmat-scale"));
        else if (a == "--rmat-ef")
            o.rmat_ef = atoi(need("--rmat-ef"));
        else if (a == "--category")
            o.category = need("--category");
        else if (a == "--impl")
            o.impl = need("--impl");
        else if (a == "--sources")
            o.sources = atoi(need("--sources"));
        else if (a == "--trials")
            o.trials = atoi(need("--trials"));
        else if (a == "--warmup")
            o.warmup = atoi(need("--warmup"));
        else if (a == "--serial-trials")
            o.serial_trials = atoi(need("--serial-trials"));
        else if (a == "--seed")
            o.seed = strtoull(need("--seed"), nullptr, 10);
        else if (a == "--block") {
            o.nc.block_size = o.ac.block_size = atoi(need("--block"));
        } else if (a == "--max-blocks") {
            o.nc.max_blocks = o.ac.max_blocks = atoi(need("--max-blocks"));
        } else if (a == "--warp-thresh")
            o.ac.warp_thresh = atoi(need("--warp-thresh"));
        else if (a == "--block-thresh")
            o.ac.block_thresh = atoi(need("--block-thresh"));
        else if (a == "--bucket-mode")
            o.ac.bucket_mode =
                (std::string(need("--bucket-mode")) == "fused") ? BUCKET_FUSED : BUCKET_SCAN;
        else if (a == "--no-streams")
            o.ac.enable_streams = false;
        else if (a == "--no-block-bucket")
            o.ac.enable_block_bucket = false;
        else if (a == "--out")
            o.out = need("--out");
        else if (a == "--tag")
            o.tag = need("--tag");
        else if (a == "--trace-out")
            o.trace_out = need("--trace-out");
        else if (a == "--structural")
            o.structural = true;
        else if (a == "--gpu-info")
            o.gpu_info = true;
        else {
            fprintf(stderr, "unknown option %s\n", a.c_str());
            usage();
            return false;
        }
    }
    return true;
}

// ------------------------------------------------------------------ CSV rows (schema is part of the
// frozen contract)
struct Row {
    std::string tag, graph, category, impl, bucket_mode = "-";
    long long n = 0, m = 0;
    int source_idx = 0, source = 0, trial = 0;
    int block_size = 0, max_blocks = 0, warp_thresh = 0, block_thresh = 0, streams = 0,
        block_bucket = 0;
    double time_ms = 0;
    int iterations = 0, levels = 0;
    long long edges_traversed = 0;
    int verified = 1;
};
static const char* CSV_HEADER =
    "tag,graph,category,n,m,impl,source_idx,source,trial,block_size,max_blocks,warp_thresh,block_thresh,"
    "bucket_mode,streams,block_bucket,time_ms,iterations,levels,edges_traversed,gteps,verified\n";

static void emit_row(FILE* f, const Row& r) {
    double gteps = r.time_ms > 0 ? (double)r.edges_traversed / (r.time_ms * 1e6) : 0.0;
    fprintf(f, "%s,%s,%s,%lld,%lld,%s,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%.6f,%d,%d,%lld,%.6f,%d\n",
            r.tag.c_str(), r.graph.c_str(), r.category.c_str(), r.n, r.m, r.impl.c_str(), r.source_idx,
            r.source, r.trial, r.block_size, r.max_blocks, r.warp_thresh, r.block_thresh,
            r.bucket_mode.c_str(), r.streams, r.block_bucket, r.time_ms, r.iterations, r.levels,
            r.edges_traversed, gteps, r.verified);
    fflush(f);
}

static void check_gpu_memory(const CSRGraph& g) {
    size_t freeb = 0, totalb = 0;
    CUDA_CHECK(cudaMemGetInfo(&freeb, &totalb));
    size_t need = ((size_t)g.n + 1) * 4 + (size_t)g.m * 4 + (size_t)g.n * 4 * 6 + ((size_t)64 << 20);
    if (need > freeb) {
        fprintf(stderr, "Not enough GPU memory: need ~%zu MB, free %zu MB. Use a smaller graph/scale.\n",
                need >> 20, freeb >> 20);
        exit(3);
    }
}

int main(int argc, char** argv) {
    Options o;
    if (!parse(argc, argv, o)) return 1;
    if (o.gpu_info) {
        print_gpu_info(true);
        return 0;
    }
    if (o.graph.empty() && o.rmat_scale < 0) {
        usage();
        return 1;
    }
    print_gpu_info();

    // ---------- load / generate graph ----------
    CSRGraph g;
    WallTimer load_timer;
    if (o.rmat_scale > 0) {
        g = make_rmat(o.rmat_scale, o.rmat_ef, o.seed);
        g.name = "rmat" + std::to_string(o.rmat_scale);
        if (o.category == "unknown") o.category = "rmat";
    } else if (!load_graph_auto(o.graph, g))
        return 2;
    printf("graph %s: n=%d m=%d (loaded in %.0f ms), category=%s\n", g.name.c_str(), g.n, g.m,
           load_timer.ms(), o.category.c_str());
    check_gpu_memory(g);

    std::vector<vid_t> srcs = pick_sources(g, o.sources, o.seed);
    DeviceGraph dg = upload_graph(g);

    FILE* f = fopen(o.out.c_str(), "a");
    if (!f) {
        perror(("cannot open " + o.out).c_str());
        return 4;
    }
    fseek(f, 0, SEEK_END);
    if (ftell(f) == 0) fputs(CSV_HEADER, f);

    auto base_row = [&](const std::string& impl, int si, int trial) {
        Row r;
        r.tag = o.tag;
        r.graph = g.name;
        r.category = o.category;
        r.n = g.n;
        r.m = g.m;
        r.impl = impl;
        r.source_idx = si;
        r.source = srcs[si];
        r.trial = trial;
        if (impl == "naive") {
            r.block_size = o.nc.block_size;
            r.max_blocks = o.nc.max_blocks;
        }
        if (impl == "adaptive") {
            r.block_size = o.ac.block_size;
            r.max_blocks = o.ac.max_blocks;
            r.warp_thresh = o.ac.warp_thresh;
            r.block_thresh = o.ac.block_thresh;
            r.bucket_mode = (o.ac.bucket_mode == BUCKET_FUSED) ? "fused" : "scan";
            r.streams = o.ac.enable_streams;
            r.block_bucket = o.ac.enable_block_bucket;
        }
        return r;
    };

    // ---------- Phase 1: serial reference (single thread, nothing else running) ----------
    const int S = (int)srcs.size();
    std::vector<std::vector<int>> ref(S);
    std::vector<long long> edges(S);
    std::vector<int> nlevels(S);
    for (int si = 0; si < S; ++si) {
        for (int t = 0; t < o.serial_trials; ++t) {
            std::vector<int> lv;
            WallTimer w;
            bfs_serial(g, srcs[si], lv);
            double ms = w.ms();
            if (t == 0) {
                edges[si] = count_traversed_edges(g, lv);
                nlevels[si] = count_levels(lv);
                ref[si] = std::move(lv);
            }
            Row r = base_row("serial", si, t);
            r.time_ms = ms;
            r.levels = nlevels[si];
            r.edges_traversed = edges[si];
            r.iterations = nlevels[si];
            emit_row(f, r);
        }
        printf("  serial   src=%d levels=%d edges=%lld\n", srcs[si], nlevels[si], edges[si]);
    }

    // ---------- Phase 2: GPU implementations; validation + logging overlap the next GPU trial (OpenMP
    // tasks) ----------
    std::atomic<int> failures(0);
    auto run_once = [&](const std::string& impl, vid_t s, std::vector<int>& lv, BFSStats& st,
                        bool trace) {
        if (impl == "naive")
            bfs_naive_cuda(dg, s, lv, o.nc, st);
        else {
            AdaptiveConfig c = o.ac;
            c.trace = trace;
            bfs_adaptive_cuda(dg, s, lv, c, st);
        }
    };
    std::vector<std::string> impls;
    if (o.impl == "naive" || o.impl == "both") impls.push_back("naive");
    if (o.impl == "adaptive" || o.impl == "both") impls.push_back("adaptive");

#pragma omp parallel
#pragma omp single
    {
        for (const std::string& impl : impls) {
            for (int si = 0; si < S; ++si) {
                for (int w = 0; w < o.warmup; ++w) {
                    std::vector<int> lv;
                    BFSStats st;
                    run_once(impl, srcs[si], lv, st, false);
                }
                for (int t = 0; t < o.trials; ++t) {
                    std::vector<int> lv;
                    BFSStats st;
                    run_once(impl, srcs[si], lv, st, false);  // <-- the only timed region
                    auto sp = std::make_shared<std::vector<int>>(std::move(lv));
                    Row r = base_row(impl, si, t);
                    r.time_ms = st.kernel_ms;
                    r.iterations = st.iterations;
                    r.levels = nlevels[si];
                    r.edges_traversed = edges[si];
#pragma omp task firstprivate(sp, r, si)
                    {
                        ValidationResult v = compare_levels(ref[si], *sp);
                        if (v.ok && o.structural) v = validate_levels_structural(g, r.source, *sp);
                        r.verified = v.ok ? 1 : 0;
                        if (!v.ok) {
                            ++failures;
#pragma omp critical(bench_io)
                            fprintf(stderr, "VERIFICATION FAILED impl=%s graph=%s src=%d: %s\n",
                                    r.impl.c_str(), r.graph.c_str(), r.source, v.msg.c_str());
                        }
#pragma omp critical(bench_csv)
                        emit_row(f, r);
                    }
                }
#pragma omp taskwait
                printf("  %-8s src=%d done\n", impl.c_str(), srcs[si]);
            }
        }
    }
    fclose(f);

    // ---------- optional per-level trace (one extra, untimed adaptive run) ----------
    if (!o.trace_out.empty() && (o.impl == "adaptive" || o.impl == "both")) {
        std::vector<int> lv;
        BFSStats st;
        run_once("adaptive", srcs[0], lv, st, true);
        FILE* tf = fopen(o.trace_out.c_str(), "a");
        if (tf) {
            fseek(tf, 0, SEEK_END);
            if (ftell(tf) == 0) fputs("graph,source,level,frontier,n_low,n_mid,n_high,ms\n", tf);
            for (const LevelTrace& t : st.trace)
                fprintf(tf, "%s,%d,%d,%d,%d,%d,%d,%.6f\n", g.name.c_str(), srcs[0], t.level, t.frontier,
                        t.n_low, t.n_mid, t.n_high, t.ms);
            fclose(tf);
        }
    }
    free_graph(dg);
    if (failures > 0) {
        fprintf(stderr, "FAILED: %d verification failures\n", failures.load());
        return 5;
    }
    printf("all runs verified OK -> %s\n", o.out.c_str());
    return 0;
}
