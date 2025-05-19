# === Stage 1: Build AliceVision + Meshroom ===
FROM nvidia/cuda:11.7.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies including Boost and OpenImageIO
RUN apt-get update && apt-get install -y \
    git cmake build-essential pkg-config ninja-build \
    libgl1-mesa-dev libglew-dev libpng-dev libjpeg-dev libtiff-dev libraw-dev \
    python3 python3-pip libboost-all-dev libopencv-dev \
    qtbase5-dev qtdeclarative5-dev libqt5svg5-dev libatlas-base-dev \
    libopenexr-dev libilmbase-dev \
    libboost-dev libboost-filesystem-dev libboost-thread-dev libboost-system-dev \
    libopenimageio-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Manually install OpenImageIO to ensure all necessary binaries are available
WORKDIR /opt
RUN git clone https://github.com/OpenImageIO/oiio.git && \
    cd oiio && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

# Install nanoflann with CMake compatibility (header-only library)
WORKDIR /opt
RUN git clone https://github.com/jlblancoc/nanoflann.git && \
    mkdir -p /usr/local/include/nanoflann && \
    cp -r nanoflann/include/nanoflann.hpp /usr/local/include/nanoflann && \
    mkdir -p /usr/local/lib/cmake/nanoflann && \
    echo "include(CMakeFindDependencyMacro)" > /usr/local/lib/cmake/nanoflann/nanoflannConfig.cmake && \
    echo "add_library(nanoflann INTERFACE)" >> /usr/local/lib/cmake/nanoflann/nanoflannConfig.cmake && \
    echo "target_include_directories(nanoflann INTERFACE /usr/local/include)" >> /usr/local/lib/cmake/nanoflann/nanoflannConfig.cmake

# Install Python dependencies
RUN pip3 install numpy

# Set Boost and nanoflann CMake paths and Boost_ROOT variable
ENV BOOST_ROOT=/usr/include/boost
ENV CMAKE_PREFIX_PATH="/usr/local/lib/cmake:/usr/lib/x86_64-linux-gnu/cmake:/usr/local/lib/cmake/nanoflann:/usr/local/lib/cmake/oiio"

# Build AliceVision
WORKDIR /opt
RUN git clone --recursive https://github.com/alicevision/AliceVision.git
WORKDIR /opt/AliceVision
RUN mkdir build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH && make -j$(nproc)

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

# Runtime dependencies including OpenImageIO and Boost
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglew2.1 libpng16-16 libjpeg8 libtiff5 libraw19 \
    qt5-default libqt5svg5 python3 python3-pip libboost-all-dev \
    unzip curl awscli libopenimageio-dev && apt-get clean

# Install Python dependencies for runtime
RUN pip3 install numpy boto3

# Entrypoint script to manage S3 and Meshroom
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Meshroom & AliceVision binaries from build stage
COPY --from=builder /opt/meshroom /opt/meshroom
COPY --from=builder /opt/AliceVision/build/install /opt/alicevision

ENV PATH="/opt/alicevision/bin:$PATH"
WORKDIR /opt/meshroom

ENTRYPOINT ["/entrypoint.sh"]