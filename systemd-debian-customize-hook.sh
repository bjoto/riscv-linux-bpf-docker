#!/bin/bash
# SPDX-FileCopyrightText: 2023 Rivos Inc.
#
# SPDX-License-Identifier: Apache-2.0

echo rivos > "$1/etc/hostname"
echo 44f789c720e545ab8fb376b1526ba6ca > "$1/etc/machine-id"

mkdir -p "$1/etc/systemd/system/serial-getty@ttyS0.service.d"
cat > "$1/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf" << "EOF"
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \u' --keep-baud --autologin root 115200,57600,38400,9600 - $TERM
EOF

cat > "$1/etc/sysctl.d/10-console-messages.conf" << "EOF"
kernel.printk = 7 4 1 7
EOF

cat > "$1/etc/systemd/network/lan0.network" << "EOF"
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

chroot "$1" sh -c 'systemctl enable systemd-networkd'

cat >"$1/root/.profile" <<"EOF"
set -x
rm -f /shutdown-status
dmesg -t > /dmesg

if [ -x /dotest ]; then
   /dotest
fi

rm -f /shutdown-status
echo "clean" > /shutdown-status
chmod 644 /shutdown-status

poweroff
EOF

