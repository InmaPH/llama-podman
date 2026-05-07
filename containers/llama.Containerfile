# -------------------------
# Build stage
# -------------------------
FROM fedora:43 AS builder

# Install dependencies
RUN dnf install -y \
    git \
    cmake \
    gcc \
    gcc-c++ \
    make \
    openblas-devel \
    mesa-vulkan-drivers \
    vulkan-tools \
    vulkan-loader-devel \
    pkgconf-pkg-config \
    ca-certificates \
    wget \
    curl \
    && dnf clean all && rm -rf /var/cache/dnf

WORKDIR /src

ARG LLAMA_VERSION=b8901

# Clone the llama.cpp repo
RUN git clone --depth 1 --branch ${LLAMA_VERSION} \
    https://github.com/ggerganov/llama.cpp.git

# Download and install Vulkan SDK (specific version)
RUN curl -LO https://sdk.lunarg.com/sdk/download/1.4.341.1/linux/vulkansdk-linux-x86_64-1.4.341.1.tar.xz && \
    tar -xvJf vulkansdk-linux-x86_64-1.4.341.1.tar.xz -C /opt/ && \
    rm vulkansdk-linux-x86_64-1.4.341.1.tar.xz

# Set environment variables for Vulkan SDK
ENV VULKAN_SDK=/opt/1.4.341.1/x86_64
ENV PATH=$VULKAN_SDK/bin:$PATH
ENV LD_LIBRARY_PATH=$VULKAN_SDK/lib:$LD_LIBRARY_PATH
ENV VK_ICD_FILENAMES=$VULKAN_SDK/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=$VULKAN_SDK/etc/vulkan/explicit_layer.d

# Build llama.cpp
RUN cd llama.cpp && \
    cmake -B build \
        -DGGML_VULKAN=ON \
        -DGGML_NATIVE=ON \
        -DGGML_AVX2=ON \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build -j$(nproc) && \
    strip build/bin/llama-server


# -------------------------
# Runtime stage
# -------------------------
FROM fedora:43

# Install necessary runtime dependencies
RUN dnf install -y \
    openblas \
    mesa-vulkan-drivers \
    vulkan-loader \
    tini \
    && dnf clean all

# Copy Vulkan SDK from the builder stage to runtime
COPY --from=builder /opt/1.4.341.1/x86_64 /opt/1.4.341.1/x86_64

# Set environment variables for Vulkan SDK
ENV VULKAN_SDK=/opt/1.4.341.1/x86_64
ENV PATH=$VULKAN_SDK/bin:$PATH
ENV LD_LIBRARY_PATH=$VULKAN_SDK/lib:$LD_LIBRARY_PATH
ENV VK_ICD_FILENAMES=$VULKAN_SDK/etc/vulkan/icd.d/nvidia_icd.json
ENV VK_LAYER_PATH=$VULKAN_SDK/etc/vulkan/explicit_layer.d

# Create a non-root user
RUN useradd -m -u 1000 llama

WORKDIR /app

# Copy the llama-server binary from the builder stage
COPY --from=builder /src/llama.cpp/build/bin/llama-server /app/llama-server
COPY containers/llama.entrypoint.sh /entrypoint.sh

# Set permissions for the llama server and entrypoint
RUN chmod 555 /app/llama-server && \
    chmod 500 /entrypoint.sh && \
    mkdir -p /models && \
    chown -R llama:llama /app /models

USER llama

# Set Vulkan-related environment variables
ENV GGML_VULKAN_VISIBLE_DEVICES=0
ENV VK_LOADER_DEBUG=error

# Expose the necessary port
EXPOSE 8080

# Healthcheck to ensure llama-server is running
HEALTHCHECK CMD pgrep llama-server || exit 1

# Entry point for the container
ENTRYPOINT ["/usr/bin/tini", "--", "/llama.entrypoint.sh"]