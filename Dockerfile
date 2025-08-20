# Args for Build actions
ARG BUILDPLATFORM_builder=linux/amd64
ARG BUILDPLATFORM_runner=linux/arm64

# Stage 1: Builder Docker
FROM --platform=$BUILDPLATFORM_builder debian:trixie-slim AS builder

# add arm64 deps
RUN dpkg --add-architecture arm64

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
    libcurl4-openssl-dev \
    libcurl4-openssl-dev:arm64 \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    libcurl4-openssl-dev:arm64 \
    libssl-dev:arm64 \
    pkg-config \
    && update-ca-certificates

WORKDIR /workspace

# Clone the repo
RUN git clone --depth=1 https://github.com/ggml-org/llama.cpp .

# Set your cross compilers environment variables (adjust if needed)
ENV CC64=aarch64-linux-gnu-gcc
ENV CXX64=aarch64-linux-gnu-g++
ENV PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
ENV PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig

# remove 'armv9' since gcc-12 doesn't support it
RUN sed -i '/armv9/d' "ggml/src/CMakeLists.txt"

# Run CMake configure and build
RUN cmake -S . -B build \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=$CC64 \
    -DCMAKE_CXX_COMPILER=$CXX64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCURL_INCLUDE_DIR=/usr/aarch64-linux-gnu/include \
    -DCURL_LIBRARY=/usr/aarch64-linux-gnu/lib/libcurl.so \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON && \
    cmake --build build -j $(nproc)

RUN mkdir -p /app/full \
    && cp build/bin/* /app/full \
    && cp *.py /app/full \
    && cp -r gguf-py /app/full \
    && cp -r requirements /app/full \
    && cp requirements.txt /app/full \
    && cp .devops/tools.sh /app/full/tools.sh

# Stage 2: Runtime
FROM --platform=$BUILDPLATFORM_runner debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopenblas-dev \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built binaries from builder
COPY --from=builder /app/full /app

# Human-readable version label
ARG LLAMA_COMMIT=unknown
LABEL llama.version=$LLAMA_COMMIT

# Default command to run your app binary
CMD ["/bin/bash"]
