# Makefile -- OWNER: Member 1.
# Recipes start with '>' instead of TAB (.RECIPEPREFIX), so copy/paste is safe.
.RECIPEPREFIX = >

NVCC ?= nvcc
CXX ?= g++
ARCH ?= native       # set e.g. ARCH=sm_75 if 'native' is rejected by your nvcc
CCBIN ?=             # e.g. CCBIN=g++-11 if your default g++ is too new for your CUDA toolkit
OPT ?= -O3

CXXFLAGS = $(OPT) -std=c++17 -fopenmp -Wall -Wextra -Iinclude -MMD -MP
NVFLAGS = $(OPT) -std=c++17 -arch=$(ARCH) -lineinfo -Iinclude -MMD -MP \
          $(if $(CCBIN),-ccbin $(CCBIN),) -Xcompiler -fopenmp,-Wall
LDLIBS = -lgomp

HOST_SRC = src/graph_io.cpp src/graph_gen.cpp src/bfs_serial.cpp src/validate.cpp src/graph_stats.cpp
HOST_OBJ = $(HOST_SRC:src/%.cpp=build/%.o)

.PHONY: all host gpu clean test
all: host gpu
host: bin/graph_tool bin/test_host
gpu: bin/bench bin/test_naive bin/test_adaptive

build/%.o: src/%.cpp
> @mkdir -p build
> $(CXX) $(CXXFLAGS) -c $< -o $@

build/%.cu.o: src/%.cu
> @mkdir -p build
> $(NVCC) $(NVFLAGS) -c $< -o $@

build/tool_%.o: tools/%.cpp
> @mkdir -p build
> $(CXX) $(CXXFLAGS) -c $< -o $@

build/test_%.o: tests/test_%.cpp
> @mkdir -p build
> $(CXX) $(CXXFLAGS) -c $< -o $@

build/test_%.cu.o: tests/test_%.cu
> @mkdir -p build
> $(NVCC) $(NVFLAGS) -c $< -o $@

bin/graph_tool: build/tool_graph_tool.o $(HOST_OBJ)
> @mkdir -p bin
> $(CXX) -fopenmp $^ -o $@

bin/test_host: build/test_host.o $(HOST_OBJ)
> @mkdir -p bin
> $(CXX) -fopenmp $^ -o $@

bin/bench: build/bench.cu.o build/bfs_naive.cu.o build/bfs_adaptive.cu.o $(HOST_OBJ)
> @mkdir -p bin
> $(NVCC) $(if $(CCBIN),-ccbin $(CCBIN),) -arch=$(ARCH) $^ -o $@ $(LDLIBS)

bin/test_naive: build/test_naive.cu.o build/bfs_naive.cu.o $(HOST_OBJ)
> @mkdir -p bin
> $(NVCC) $(if $(CCBIN),-ccbin $(CCBIN),) -arch=$(ARCH) $^ -o $@ $(LDLIBS)

bin/test_adaptive: build/test_adaptive.cu.o build/bfs_adaptive.cu.o $(HOST_OBJ)
> @mkdir -p bin
> $(NVCC) $(if $(CCBIN),-ccbin $(CCBIN),) -arch=$(ARCH) $^ -o $@ $(LDLIBS)

test: bin/test_host
> ./bin/test_host

clean:
> rm -rf build bin

-include build/*.d
