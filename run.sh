#!/bin/bash

test_string=${1:-"self-bpf-all"}

case ${test_string} in
    "self-all")
    ;;
    "self-net")
    ;;
    "self-bpf-all")
    ;;
    "self-bpf-test_progs")
    ;;
    "self-bpf-test_progs_no_alu32")
    ;;
    "self-bpf-test_progs_cpuv4")
    ;;
    "self-bpf-test_maps")
    ;;
    "self-bpf-test_verifier")
    ;;
    *)
	echo "::error::Not a valid test_string"
	exit 1
        ;;
esac
    
echo "::notice::test_string: ${test_string}"

cd /build/my-linux
/usr/local/bin/ci/prepare_tests.sh
/usr/local/bin/ci/kernel_builder.sh rv64 kselftest plain gcc
/usr/local/bin/ci/kselftest_builder.sh rv64 kselftest plain gcc
/usr/local/bin/ci/test_runner.sh rv64 kselftest plain gcc ubuntu ${test_string}
for i in /build/tests/run_test_*; do
    echo "::group::Dumping $i"
    cat $i
    echo "::endgroup::"
done
