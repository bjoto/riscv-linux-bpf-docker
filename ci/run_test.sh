#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

# Executes the VMs, and report.

set -x
set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")

log_dir=/build/tests
firmware_dir=/build/firmware

kernel=$1          # e.g. rv64_gcc_defconfig_plain
rootfs=$2          #      rootfs_rv64_alpine_2023.03.13.tar.xz
selftest=$3
test_string=$4

qemu_rv64 () {
    local bios=$1
    local cpu=$2
    local krnl=$3
    local extra=$4
    local log=$5

    timeout --foreground 24h qemu-system-riscv64 \
        -no-reboot \
        -bios $bios \
        -nodefaults \
        -nographic \
        -machine virt,acpi=off \
        -cpu $cpu \
        -smp 4 \
        -object rng-random,filename=/dev/urandom,id=rng0 \
        -device virtio-rng-device,rng=rng0 \
        -kernel $krnl \
        -append "root=/dev/vda2 rw earlycon console=tty0 console=ttyS0 panic=-1 oops=panic sysctl.vm.panic_on_oom=1" \
        -m 4G \
        -chardev stdio,id=char0,mux=on,signal=off,logfile="$log" \
        -serial chardev:char0 \
        -drive if=none,file=$image,format=raw,id=hd0 \
        -device virtio-blk-pci,drive=hd0 ${extra}
}

check_boot () {
    local n=$1

    # Soft fallback to TCG is broken on aarch64, but forcing TCG works.
    export LIBGUESTFS_BACKEND_SETTINGS=force_tcg
    shutdown="$(guestfish --ro -a "$image" -i cat /shutdown-status 2>/dev/null)"
    if [[ $shutdown == "clean" ]]; then
        echo "$n OK"
        guestfish --rw -a "$image" -i download /dmesg ${log_dir}/${n}-dmesg
        guestfish --rw -a $image -i rm /shutdown-status || true
    else
        echo "$n FAIL"
        exit 1
    fi
}

tmp=$(mktemp -d -p "$PWD")

trap 'rm -rf "$tmp"' EXIT

mkdir -p ${log_dir}

vmlinuz=$(find $kernel -name '*vmlinuz*')
config=$(find $kernel -name 'config-*')

image=$tmp/rootfs.img
$d/prepare_rootfs.sh $image $kernel $rootfs $selftest ${test_string}

if [[ $kernel =~ "rv64" ]]; then
    list_cpus=( "rv64,v=true,vlen=256,elen=64,h=true,zbkb=on,zbkc=on,zbkx=on,zkr=on,zkt=on,svinval=on,svnapot=on,svpbmt=on" )
    # list_cpus=( "rv64" "rv64,v=true,vlen=256,elen=64,h=true,zbkb=on,zbkc=on,zbkx=on,zkr=on,zkt=on,svinval=on,svnapot=on,svpbmt=on" )
    # if grep -q 'CONFIG_RISCV_ALTERNATIVE_EARLY=y' $config; then
    #     list_cpus+=( "sifive-u54" "thead-c906" )
    # fi

    for cpu in "${list_cpus[@]}"; do
        n=$(basename $kernel .tar.xz)-$(basename $rootfs .tar.xz)-${cpu//,/-}
        # qemu_rv64 "${firmware_dir}/rv64/fw_dynamic.bin" "$cpu" "$vmlinuz" "" \
        #           "${log_dir}/${n}.log"
        #
        # check_boot "$n"

        if [[ -n $config ]] && grep -q 'CONFIG_EFI=y' $config; then
            # UEFI boot with uboot
            n=${n}-uboot-uefi
            qemu_rv64 "${firmware_dir}/rv64/fw_dynamic.bin" "$cpu" "${firmware_dir}/rv64/rv64-u-boot.bin" "" \
                      "${log_dir}/${n}.log"

            check_boot "$n"

            # UEFI boot with edk2
            # n=${n}-uboot-edk2
            # qemu_rv64 "${firmware_dir}/rv64/fw_dynamic.bin" "$cpu" "$vmlinuz" \
            #         "-drive file=${firmware_dir}/rv64/RISCV_VIRT.fd,if=pflash,format=raw,unit=1"
            # check_boot "$n"
        else
            echo "$n UEFI SKIPPED"
            exit 1
        fi
    done
else
    echo "CANNOT TEST $(basename $kernel .tar.xz)"
    exit 1
fi
