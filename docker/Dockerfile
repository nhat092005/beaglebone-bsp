# ubuntu:22.04 digest pinned 2026-04-18 — update with: docker pull ubuntu:22.04 && docker inspect ubuntu:22.04 --format='{{index .RepoDigests 0}}'
FROM ubuntu@sha256:962f6cadeae0ea6284001009daa4cc9a8c37e75d1f5191cf0eb83fe565b63dd7

ENV DEBIAN_FRONTEND=noninteractive

RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

RUN sed -i 's|http://archive.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com|http://vn.archive.ubuntu.com|g' /etc/apt/sources.list

# Layer 1 — cross-compiler & kernel build deps
RUN apt-get update && apt-get install -y \
    gcc \
    gcc-arm-linux-gnueabihf=4:11.2.0-1ubuntu1 \
    binutils-arm-linux-gnueabihf \
    libssl-dev \
    libelf-dev \
    libyaml-dev \
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
    shellcheck \
    cppcheck \
    diffoscope \
    swig \
    && rm -rf /var/lib/apt/lists/*

# Layer 4 — locale (required by Yocto sanity checker)
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Layer 5 — dtschema for Device Tree validation
RUN pip3 install --no-cache-dir dtschema

ENV CROSS_COMPILE=arm-linux-gnueabihf- \
    ARCH=arm \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN useradd -m -u 1000 builder

USER builder

WORKDIR /workspace
