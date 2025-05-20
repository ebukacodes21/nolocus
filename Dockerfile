# ---- Build Stage ----
FROM nvidia/cuda:11.7.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git cmake build-essential libpng-dev libjpeg-dev libtiff-dev libgl1-mesa-glx \
    libglew-dev libboost-all-dev python3 python3-pip libopencv-dev wget unzip \
    qtbase5-dev qtdeclarative5-dev libqt5svg5-dev libopenexr-dev libraw-dev \
    exiftool \
    && rm -rf /var/lib/apt/lists/*

# Clone Meshroom
WORKDIR /opt
RUN git clone --recursive https://github.com/alicevision/meshroom.git

# Build AliceVision engine
WORKDIR /opt/meshroom
RUN ./build.sh

# Install Python packages for depth + geo
RUN pip3 install torch torchvision opencv-python exifread matplotlib \
    git+https://github.com/isl-org/MiDaS.git

# ---- Runtime Stage ----
FROM nvidia/cuda:11.7.1-runtime-ubuntu22.04

# Copy Meshroom and Python env
COPY --from=builder /opt/meshroom /opt/meshroom

# Copy MiDaS model and helper script
COPY --from=builder /root/.cache /root/.cache
COPY --from=builder /usr/local/lib/python3.10 /usr/local/lib/python3.10
COPY --from=builder /usr/local/bin /usr/local/bin

# Optional: copy helper script to do depth + geo
COPY preprocessor.py /app/preprocessor.py

WORKDIR /data

# Default entrypoint is Meshroom, but can be overridden
ENTRYPOINT ["/opt/meshroom/meshroom_batch"]