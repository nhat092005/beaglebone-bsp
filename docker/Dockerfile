FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

RUN sed -i 's|http://archive.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list

# Layer 1 — cross-compiler & kernel build deps
RUN apt-get update && apt-get install -y \
    gcc \
    gcc-arm-linux-gnueabihf \
    binutils-arm-linux-gnueabihf \
    libssl-dev \
    libelf-dev \
    && rm -rf /var/lib/apt/lists/*

# Layer 2 — kernel & buildroot tools
RUN apt-get update && apt-get install -y \
    make \
    bc \
    flex \
    bison \
    device-tree-compiler \
    u-boot-tools \
    gawk \
    diffstat \
    texinfo \
    chrpath \
    && rm -rf /var/lib/apt/lists/*

# Layer 3 — scripting, fetch & misc utils
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
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

# Layer 4 — locale (required by Yocto sanity checker)
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV CROSS_COMPILE=arm-linux-gnueabihf- \
    ARCH=arm \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN useradd -m -u 1000 builder

USER builder

WORKDIR /workspace
