# === Stage 1: Build AliceVision + Meshroom ===
FROM nvidia/cuda:11.7.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    git cmake build-essential pkg-config ninja-build \
    libgl1-mesa-dev libglew-dev libpng-dev libjpeg-dev libtiff-dev libraw-dev \
    python3 python3-pip libboost-all-dev libopencv-dev \
    qtbase5-dev qtdeclarative5-dev libqt5svg5-dev libatlas-base-dev \
    libopenexr-dev libimath-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 

RUN pip3 install numpy

# Build AliceVision
WORKDIR /opt
RUN git clone --recursive https://github.com/alicevision/AliceVision.git
WORKDIR /opt/AliceVision
RUN mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)

# Build Meshroom
WORKDIR /opt
RUN git clone --recursive https://github.com/alicevision/meshroom.git
WORKDIR /opt/meshroom
ENV ALICEVISION_INSTALL=/opt/AliceVision/build/install
ENV PATH="${ALICEVISION_INSTALL}/bin:$PATH"
RUN ./build.sh

# === Stage 2: Runtime Image ===
FROM nvidia/cuda:11.7.1-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglew2.1 libpng16-16 libjpeg8 libtiff5 libraw19 \
    qt5-default libqt5svg5 python3 python3-pip libboost-all-dev \
    unzip curl awscli && apt-get clean

RUN pip3 install numpy boto3

# Entrypoint script to manage S3 and Meshroom
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Meshroom & AliceVision binaries
COPY --from=builder /opt/meshroom /opt/meshroom
COPY --from=builder /opt/AliceVision/build/install /opt/alicevision

ENV PATH="/opt/alicevision/bin:$PATH"
WORKDIR /opt/meshroom

ENTRYPOINT ["/entrypoint.sh"]