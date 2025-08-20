# Stage 1: Builder Docker
# FROM debian:bookworm-slim AS builder

# Install build dependencies
#RUN add-apt-repository ppa:ubuntu-toolchain-r/test
#RUN apt-get update && apt-get install -y \
#    build-essential \
#    cmake \
#    git \
#    curl \
#    ninja-build \
#    ca-certificates \
#    libopenblas-dev \
#    libgomp1 \
#    libcurl4-openssl-dev \
#    && update-ca-certificates
FROM --platform=linux/amd64 archlinux:multilib-devel AS builder

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      cmake \
      git \
      curl \
      ninja \
      openblas \
      gcc \
      libcurl-compat

WORKDIR /workspace

# Clone the repo
RUN git clone --depth=1 https://github.com/ggml-org/llama.cpp .

# Set your cross compilers environment variables (adjust if needed)
ENV CC64=aarch64-linux-gnu-gcc
ENV CXX64=aarch64-linux-gnu-g++

# Run CMake configure and build
RUN cmake -S . -B build \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=$CC64 \
    -DCMAKE_CXX_COMPILER=$CXX64 \
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
COPY --from=builder /app/full /app

# Human-readable version label
ARG LLAMA_COMMIT=unknown
LABEL llama.version=$LLAMA_COMMIT

# Default command to run your app binary
CMD ["/bin/bash"]
