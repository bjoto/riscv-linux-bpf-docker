#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

# Builds an RV64 Ubuntu rootfs.

set -euo pipefail

set -x

d=$(dirname "${BASH_SOURCE[0]}")
distro=mantic

packages=(
	systemd-sysv
	udev
        binutils
        elfutils
        ethtool
        iproute2
        iptables
        keyutils
        libcap2
        libelf1
        openssl
        strace
        zlib1g
)
packages=$(IFS=, && echo "${packages[*]}")

name="rootfs_rv64_ubuntu_$(date +%Y.%m.%d).tar"

mmdebstrap --include="$packages" \
           --architecture=riscv64 \
	   --components="main restricted multiverse universe" \
	   --customize-hook=$d/systemd-debian-customize-hook.sh \
	   --skip=cleanup/reproducible \
           "${distro}" \
           "${name}"

xz -9 -T0 $name
