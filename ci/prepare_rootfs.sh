#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

# Prepares a VM image, from a kernel tar-ball and a rootfs.

set -euo pipefail

d=$(dirname "${BASH_SOURCE[0]}")

# e.g. super-duper-image.img
imagename=$1
# e.g. untarred linux_ubuntu_rv64_gcc_defconfig_plain.tar.xz
kernelpath=$2
# e.g rootfs_rv64_alpine_2023.03.13.tar.xz
rootfs=$3
selftest=$4
test_string=$5
opaque=${6:-}

tmp=$(mktemp -d -p /build)

cleanup() {
    rm -rf "$tmp"
}
trap cleanup EXIT

unxz --keep --stdout $rootfs > $tmp/$(basename $rootfs .xz)

rootfs="$tmp/$(basename $rootfs .xz)"
modpath=$(find $kernelpath -wholename '*/lib/modules')
vmlinuz=$(find $kernelpath -name '*vmlinuz*')

rm -rf $imagename

imsz=1
if [[ -n $modpath ]]; then
    imsz=$(du -B 1G -s "$modpath" | awk '{print $1}')
fi

imsz=$(( ${imsz} + 1 ))

# Soft fallback to TCG is broken on aarch64, but forcing TCG works.
export LIBGUESTFS_BACKEND_SETTINGS=force_tcg
eval "$(guestfish --listen)"

guestfish --remote -- \
          disk-create "$imagename" raw ${imsz}G : \
          add-drive "$imagename" format:raw : \
          launch : \
          part-init /dev/sda gpt : \
          part-add /dev/sda primary 2048 526336 : \
          part-add /dev/sda primary 526337 -34 : \
          part-set-gpt-type /dev/sda 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B : \
          mkfs ext4 /dev/sda2 : \
          mount /dev/sda2 / : \
          mkdir /boot : \
          mkdir /boot/efi : \
          mkfs vfat /dev/sda1 : \
          mount /dev/sda1 /boot/efi : \
          tar-in $rootfs / : \
          copy-in $vmlinuz /boot/efi/ : \
          mv /boot/efi/$(basename $vmlinuz) /boot/efi/Image


if [[ -n $modpath ]]; then
    guestfish --remote -- copy-in $modpath /lib/
fi

if [[ -n $selftest ]]; then
    guestfish --remote -- \
              mkdir /kselftest : \
              tar-in $selftest /kselftest
fi

if [[ -n ${test_string} ]]; then
    touch $tmp/dotest
    chmod +x $tmp/dotest
    cat >$tmp/dotest <<EOF
#!/bin/bash

set -x
echo "<5>Hello" > /dev/kmsg
cd /kselftest

EOF
    case ${test_string} in
        "self-all")
            cat >>$tmp/dotest <<EOF
for i in $(./run_kselftest.sh -l|awk -F: '{print $1}' |uniq |egrep -v 'bpf|net|lkdtm|breakpoints'); do
    echo "TEST $i"
    ./run_kselftest.sh -s -o 3600 -c $i ${opaque}
done
EOF
            ;;
        "self-net")
            cat >>$tmp/dotest <<EOF
echo "TEST net"
./run_kselftest.sh -s -o 3600 -c net ${opaque}
EOF
            ;;
        "self-bpf-all")
            cat >>$tmp/dotest <<EOF
echo "TEST bpf"
./run_kselftest.sh -s -o 7200 -c bpf ${opaque}
EOF
            ;;
        "self-bpf-test_progs")
            cat >>$tmp/dotest <<EOF
cd bpf
./test_progs ${opaque}
EOF
            ;;
        "self-bpf-test_progs_no_alu32")
            cat >>$tmp/dotest <<EOF
cd bpf
./test_progs-no_alu32 ${opaque}
EOF
            ;;
        "self-bpf-test_progs_cpuv4")
            cat >>$tmp/dotest <<EOF
cd bpf
./test_progs-cpuv4 ${opaque}
EOF
            ;;
        "self-bpf-test_maps")
            cat >>$tmp/dotest <<EOF
cd bpf
./test_maps ${opaque}
EOF
            ;;
        "self-bpf-test_verifier")
            cat >>$tmp/dotest <<EOF
cd bpf
./test_verifier ${opaque}
EOF
            ;;
        "command")
            cat >>$tmp/dotest <<EOF
${opaque}
EOF
            ;;
        "debug")
	    guestfish --remote -- rm /root/.profile
            ;;
        *)
            cat >>$tmp/dotest <<EOF
echo "Not a valid test_string"
EOF
            ;;
    esac

    echo "dotest:"
    cat $tmp/dotest
    echo "dotest end"
    guestfish --remote -- \
              copy-in $tmp/dotest /
fi

guestfish --remote -- \
          sync : \
          umount /boot/efi : \
          umount / : \
          exit
