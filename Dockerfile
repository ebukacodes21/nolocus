# === Build Stage: Get Meshroom CLI ready ===
FROM nvidia/cuda:11.8.0-base-ubuntu20.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    git cmake build-essential libgl1-mesa-dev libglew-dev \
    libxrandr-dev libxi-dev libxxf86vm-dev libxinerama-dev \
    libjpeg-dev libpng-dev libtiff-dev libopenexr-dev \
    python3-pip python3-dev python-is-python3 wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Install AliceVision (Meshroom's photogrammetry backend)
RUN git clone https://github.com/alicevision/AliceVision.git && \
    cd AliceVision && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# Install Meshroom CLI
RUN git clone https://github.com/alicevision/meshroom.git /meshroom
WORKDIR /meshroom
RUN pip install -r requirements.txt

# === Runtime Stage: Smaller runtime with S3 support ===
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    python3-pip python3-dev python-is-python3 awscli unzip && \
    rm -rf /var/lib/apt/lists/*

# Copy Meshroom build and AliceVision binaries
COPY --from=builder /meshroom /app/meshroom
COPY --from=builder /usr/local/bin/* /usr/local/bin/
COPY --from=builder /usr/local/lib/* /usr/local/lib/

WORKDIR /app

# Add entrypoint script
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]