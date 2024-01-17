# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

ARG flavor=mantic

FROM ubuntu:${flavor}

ARG DEBIAN_FRONTEND=noninteractive
SHELL [ "/bin/bash", "--login", "-e", "-o", "pipefail", "-c" ]
WORKDIR /tmp

# Base packages to retrieve the other repositories/packages
RUN apt-get update && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg

# Add additional packages here.
RUN apt-get update && apt-get install --yes --no-install-recommends \
    arch-test \
    autoconf \
    automake \
    autotools-dev \
    bash-completion \
    bc \
    binfmt-support \
    bison \
    bsdmainutils \
    build-essential \
    ccache \
    cmake \
    cpio \
    diffstat \
    flex \
    g++-riscv64-linux-gnu \
    gawk \
    gcc-riscv64-linux-gnu \
    gdb \
    gettext \
    git \
    git-lfs \
    gperf \
    groff \
    guestfish \
    keyutils \
    kmod \
    kmod \
    less \
    less \
    libdw-dev \
    libelf-dev \
    libguestfs-tools \
    libssl-dev \
    liburing-dev \
    lsb-release \
    lsb-release \
    mmdebstrap \
    ninja-build \
    parallel \
    patchutils \
    perl \
    pkg-config \
    psmisc \
    python-is-python3 \
    python3-docutils \
    python3-venv \
    qemu-system-misc \
    qemu-user-static \
    rsync \
    ruby \
    software-properties-common \
    ssh \
    strace \
    texinfo \
    traceroute \
    unzip \
    vim \
    wget \
    zlib1g-dev

RUN echo 'deb [arch=amd64] http://apt.llvm.org/mantic/ llvm-toolchain-mantic main' >> /etc/apt/sources.list.d/llvm.list
RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc

RUN apt update
RUN apt-get install --yes clang llvm lld

# Ick. BPF requires pahole "supernew" to work
RUN cd $(mktemp -d) && git clone https://git.kernel.org/pub/scm/devel/pahole/pahole.git && \
    cd pahole && mkdir build && cd build && cmake -D__LIB=lib .. && make install

RUN dpkg --add-architecture riscv64
RUN sed -i 's/^deb/deb [arch=amd64]/' /etc/apt/sources.list
RUN echo -e '\n\
deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports mantic main restricted multiverse universe\n\
deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports mantic-updates main\n\
deb [arch=riscv64] http://ports.ubuntu.com/ubuntu-ports mantic-security main\n'\
>> /etc/apt/sources.list

RUN apt-get update

RUN apt-get install --yes --no-install-recommends \
    libasound2-dev:riscv64 \
    libc6-dev:riscv64 \
    libcap-dev:riscv64 \
    libcap-ng-dev:riscv64 \
    libelf-dev:riscv64 \
    libfuse-dev:riscv64 \
    libhugetlbfs-dev:riscv64 \
    libmnl-dev:riscv64 \
    libnuma-dev:riscv64 \
    libpopt-dev:riscv64 \
    libssl-dev:riscv64 \
    liburing-dev:riscv64

COPY mkfirmware_rv64_opensbi.sh /usr/local/bin/mkfirmware_rv64_opensbi.sh
COPY mkfirmware_rv64_uboot.sh /usr/local/bin/mkfirmware_rv64_uboot.sh

RUN mkdir -p /firmware
RUN cd /firmware && /usr/local/bin/mkfirmware_rv64_opensbi.sh
RUN cd /firmware && /usr/local/bin/mkfirmware_rv64_uboot.sh

COPY mkrootfs_rv64_ubuntu.sh /usr/local/bin/mkrootfs_rv64_ubuntu.sh
COPY systemd-debian-customize-hook.sh /usr/local/bin/systemd-debian-customize-hook.sh

RUN mkdir -p /rootfs
RUN cd /rootfs && /usr/local/bin/mkrootfs_rv64_ubuntu.sh

RUN echo 'export CCACHE_DIR=/build/ccache' >> /etc/profile
RUN echo 'export CCACHE_MAXSIZE="50G"' >> /etc/profile
RUN echo 'export KBUILD_BUILD_TIMESTAMP=@1621270510' >> /etc/profile
RUN echo 'export KBUILD_BUILD_USER=tuxmake' >> /etc/profile
RUN echo 'export KBUILD_BUILD_HOST=tuxmake' >> /etc/profile

RUN apt-get install --yes --no-install-recommends linux-image-generic

COPY ci /usr/local/bin/ci
COPY run.sh /usr/local/bin/run.sh

RUN apt-get clean && rm -rf /var/lib/apt/lists/
