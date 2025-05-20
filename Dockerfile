FROM nvidia/cuda:11.7.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget unzip python3 python3-pip git libgl1 libglib2.0-0 libxrender1 libsm6 libxext6 exiftool && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install torch torchvision opencv-python exifread matplotlib

# Clone MiDaS repo
WORKDIR /opt
RUN git clone https://github.com/isl-org/MiDaS.git

# Download Meshroom prebuilt binaries
RUN wget https://github.com/alicevision/meshroom/releases/download/2023.3.0/Meshroom-2023.3.0-linux.zip && \
    unzip Meshroom-2023.3.0-linux.zip && \
    rm Meshroom-2023.3.0-linux.zip

ENV PATH="/opt/Meshroom-2023.3.0-linux:${PATH}"

# Download weights
RUN mkdir -p /opt/MiDaS/weights && \
    wget -O /opt/MiDaS/weights/dpt_large-midas-2f21e586.pt https://github.com/isl-org/MiDaS/releases/download/v3_1/dpt_large-midas-2f21e586.pt

# Copy preprocessing script (optional)
COPY preprocessor.py /app/preprocessor.py

WORKDIR /data

ENTRYPOINT ["meshroom_batch"]
