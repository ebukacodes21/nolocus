# ============================
# Stage 1 — Builder
# ============================
FROM nvidia/cuda:11.7.1-runtime-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget unzip python3 python3-pip git libgl1 libglib2.0-0 libxrender1 libsm6 libxext6 exiftool && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install torch torchvision opencv-python exifread matplotlib

# Clone MiDaS repo and download model
WORKDIR /opt
RUN git clone --depth=1 https://github.com/isl-org/MiDaS.git && \
    mkdir -p /opt/MiDaS/weights && \
    wget -O /opt/MiDaS/weights/dpt_beit_large_384.pt https://github.com/isl-org/MiDaS/releases/download/v3_1/dpt_beit_large_384.pt

# Download and extract Meshroom
RUN wget https://github.com/alicevision/meshroom/releases/download/v2023.3.0/Meshroom-2023.3.0-linux.tar.gz && \
    tar -xzf Meshroom-2023.3.0-linux.tar.gz && \
    rm Meshroom-2023.3.0-linux.tar.gz

# ============================
# Stage 2 — Final Runtime
# ============================
FROM nvidia/cuda:11.7.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    libgl1 libglib2.0-0 libxrender1 libsm6 libxext6 exiftool python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy from builder stage
COPY --from=builder /opt/MiDaS /opt/MiDaS
COPY --from=builder /opt/Meshroom-2023.3.0-linux /opt/Meshroom
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages

# Copy script
COPY preprocessor.py /app/preprocessor.py

# Add Meshroom to path
ENV PATH="/opt/Meshroom:${PATH}"

WORKDIR /data
ENTRYPOINT ["meshroom_batch"]