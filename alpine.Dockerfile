# Stage 1: Builder
FROM alpine:3.21 AS builder

ARG GGML_CPU_ARM_ARCH=armv8-a

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    curl \
    ninja \
    openblas-dev \
    g++ \
    gcc \
    musl-dev \
    linux-headers \
    crossbuild-essential-aarch64 \
    bash

WORKDIR /workspace

# Clone llama.cpp
RUN git clone https://github.com/ggerganov/llama.cpp.git .

# Set cross compiler
ENV CC64=aarch64-linux-musl-gcc
ENV CXX64=aarch64-linux-musl-g++

RUN cmake -S . -B build \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
    -DCMAKE_C_COMPILER=$CC64 \
    -DCMAKE_CXX_COMPILER=$CXX64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DGGML_CPU_ARM_ARCH=${GGML_CPU_ARM_ARCH} \
 && cmake --build build -j $(nproc)

RUN mkdir -p /app/full \
    && cp build/bin/* /app/full \
    && cp *.py /app/full \
    && cp -r gguf-py /app/full \
    && cp -r requirements /app/full \
    && cp requirements.txt /app/full

# Stage 2: Runtime
FROM arm64v8/alpine:3.21

RUN apk add --no-cache \
    openblas-dev \
    libstdc++ \
    bash \
    curl

WORKDIR /app

COPY --from=builder /app/full /app

CMD ["/bin/bash"]
