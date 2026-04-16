FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

RUN sed -i 's|http://archive.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabihf \
    binutils-arm-linux-gnueabihf \
    make \
    bc \
    libssl-dev \
    flex \
    bison \
    libelf-dev \
    device-tree-compiler \
    u-boot-tools \
    gawk \
    wget \
    diffstat \
    unzip \
    texinfo \
    gcc \
    chrpath \
    socat \
    cpio \
    python3 \
    python3-pip \
    xz-utils \
    debianutils \
    iputils-ping \
    git \
    curl \
    file \
    rsync \
    minicom \
    && rm -rf /var/lib/apt/lists/*

ENV CROSS_COMPILE=arm-linux-gnueabihf- \
    ARCH=arm

RUN useradd -m -u 1000 builder

USER builder

WORKDIR /workspace
