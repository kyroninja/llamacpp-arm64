# ---------- Stage 1: Build llama.cpp ----------
FROM samip537/archlinux:yay AS builder

ARG LLAMA_CPP_TAG=b3042
WORKDIR /llama

# Install build dependencies
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm git base-devel cmake ninja upx && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/*

# Clone and build specific version of llama.cpp
RUN git clone --branch ${LLAMA_CPP_TAG} --depth 1 https://github.com/ggerganov/llama.cpp.git . && \
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --config Release -- -j$(nproc)

# ---------- Stage 2: Minimal Runtime ----------
FROM arm64v8/alpine:3.22

WORKDIR /llama/build/bin

# Install only minimal runtime dependencies
RUN apk add --no-cache bash libstdc++ libgcc

# Copy all built binaries
COPY --from=builder /llama/build/bin/ .

# Expose default port
EXPOSE 8080

# Default shell, so user can run binaries directly
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "echo 'Usage: docker run image <binary> [args], e.g. llama-cli --help'"]
