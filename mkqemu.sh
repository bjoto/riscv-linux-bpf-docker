#!/bin/bash
# SPDX-FileCopyrightText: 2024 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")

tmp=$(mktemp -d -p "$PWD")

trap 'rm -rf "$tmp"' EXIT

cd $tmp
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
git checkout -b v8.2.0
git submodule update --init
mkdir build
cd build
../configure --target-list=riscv64-softmmu,riscv32-softmmu
ninja install

short_sha1=`git rev-parse --short HEAD`
echo "${short_sha1}" > /usr/local/bin/qemu-system-riscv-sha1
