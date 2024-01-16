#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")

xlen=$1
config=$2
fragment=$3
toolchain=$4

n="${xlen}_${toolchain}_${config//_/-}_$(basename $fragment)"

build_dir=/build/kernels/${n}_build
install_dir=/build/kernels
log_dir=/build/kernels/logs

mkdir -p ${build_dir}
mkdir -p ${install_dir}
mkdir -p ${log_dir}

echo "::group::Building linux_${n}"
rc=0
$d/build_kernel.sh "${xlen}" "${config}" "${fragment}" "${toolchain}" \
                   "${build_dir}" "${install_dir}" \
                   > "${log_dir}/build_kernel_${n}.log" 2>&1 || rc=$?
echo "::endgroup::"
if (( $rc )); then
    echo "::error::FAIL linux_${n}"
else
    echo "::notice::OK linux_${n}"
fi
