#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -x
set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")
lnxroot=$(pwd)

toolchain=$1
output=$2
install=$3

triple=riscv64-linux-gnu-

make_gcc() {
    make O=$output ARCH=riscv CROSS_COMPILE=$triple \
         "CC=${triple}gcc" 'HOSTCC=gcc' $*
}

make_llvm() {
    make O=$output ARCH=riscv CROSS_COMPILE=$triple \
         LLVM=1 LLVM_IAS=1 'CC=clang' 'HOSTCC=clang' $*
}

make_wrap() {
    if [ $toolchain == "llvm" ]; then
        make_llvm $*
    else
        make_gcc $*
    fi
}

make_wrap headers
make_wrap FORMAT= \
  SKIP_TARGETS="arm64 ia64 powerpc sparc64 x86 sgx" -j $(($(nproc)-1)) -C tools/testing/selftests gen_tar

cp ${output}/kselftest/kselftest_install/kselftest-packages/kselftest.tar ${install}
