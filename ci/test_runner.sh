#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")

kernels_dir=/build/kernels
rootfs_dir=/rootfs
log_dir=/build/tests
selftest_dir=/build/selftests

xlen=$1
config=$2
fragment=$3
toolchain=$4
rootfs=$5
test_string=$6
opaque=${7:-}

n="${xlen}_${toolchain}_${config//_/-}_$(basename $fragment)"
lnx="${kernels_dir}/${n}"
rootfs=$(echo ${rootfs_dir}/rootfs_${xlen}_${rootfs}_*.tar.xz)
selftest=$(echo ${selftest_dir}/${n}/kselftest.tar)

mkdir -p /build/tests || true

echo "::group::Testing ${lnx} ${rootfs}"
rc=0
$d/run_test.sh "${lnx}" "${rootfs}" "${selftest}" "${test_string}" "${opaque}" \
               > "${log_dir}/run_test_$(basename ${lnx})_$(basename ${rootfs} .tar.xz).log" \
               2>&1 || rc=$?
echo "::endgroup::"
if (( $rc )); then
    echo "::error::FAIL ${lnx} ${rootfs}"
else
    echo "::notice::OK ${lnx} ${rootfs}"
fi
