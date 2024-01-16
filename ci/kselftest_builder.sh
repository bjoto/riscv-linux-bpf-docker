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
install_dir=/build/selftests/${n}
log_dir=/build/selftests/logs

mkdir -p ${install_dir}
mkdir -p ${log_dir}

if [ ! -d ${build_dir} ]; then
    echo "::error::FAIL selftest_${n} -- no kernel"
    exit 1
fi

echo "::group::Building selftest_${n}"
rc=0
$d/build_kselftest.sh "${toolchain}" "${build_dir}" "${install_dir}" \
                     > "${log_dir}/build_kselftest_${n}.log" 2>&1 || rc=$?
echo "::endgroup::"
if (( $rc )); then
    echo "::error::FAIL selftest_${n}"
else
    echo "::notice::OK selftest_${n}"
fi
