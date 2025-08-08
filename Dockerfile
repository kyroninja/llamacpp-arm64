# Stage 1: Builder
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    ninja-build \
    ca-certificates \
    libopenblas-dev \
    libgomp1 \
    && update-ca-certificates

WORKDIR /workspace

# Clone the repo
RUN git clone https://github.com/ggerganov/llama.cpp.git .

# Set your cross compilers environment variables (adjust if needed)
ENV CC64=aarch64-linux-gnu-gcc
ENV CXX64=aarch64-linux-gnu-g++

# Run CMake configure and build with your options
RUN cmake -B build \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=$CC64 \
    -DCMAKE_CXX_COMPILER=$CXX64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_CURL=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_USE_SYSTEM_GGML=OFF \
    -DGGML_ALL_WARNINGS=OFF \
    -DGGML_ALL_WARNINGS_3RD_PARTY=OFF \
    -DGGML_BUILD_EXAMPLES=OFF \
    -DGGML_BUILD_TESTS=OFF \
    -DGGML_LTO=ON \
    -DGGML_RPC=ON \
    -DGGML_BLAS=OFF \
    -DGGML_BUILD_SERVER=ON \
    -Wno-dev && \
    cmake --build build -j$(nproc)

# Stage 2: Runtime
FROM arm64v8/debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopenblas-dev \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built binaries from builder
COPY --from=builder /workspace/build /app/build

# Set working directory to build directory
WORKDIR /app/build/bin

# Default command to run your app binary
CMD ["/bin/bash"]
