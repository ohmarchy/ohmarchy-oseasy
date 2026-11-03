#!/bin/sh
# The Oseasy bridge address 172.16.100.2 for the VM NIC (NetworkManager leaves it
# alone), and, while /etc/ohmarchy/netshell exists, a root shell on tcp/5000 and
# file upload on tcp/5001 (first line = destination path, then the bytes).
# Development builds create the flag (OHMARCHY_NETSHELL=1); anyone can, then
# `systemctl restart omarchy-netremote`.
BB=/usr/local/lib/omarchy/busybox
vmnic() {
    for d in /sys/class/net/*; do
        [ "$(basename "$(readlink "$d/device/driver" 2>/dev/null)")" = virtio_net ] && { basename "$d"; return; }
    done
}
(
    while :; do
        n=$(vmnic)
        if [ -n "$n" ] && ! ip -4 addr show dev "$n" | grep -q '172\.16\.100\.2/'; then
            ip link set "$n" up
            ip addr add 172.16.100.2/24 dev "$n"
            ip route add default via 172.16.100.1 2>/dev/null
        fi
        sleep 5
    done
) &
# the chrooted server started by the initramfs may still hold the port
pkill -f 'busybox tcpsvd -E 0 5000' 2>/dev/null; sleep 0.3
if [ ! -e /etc/ohmarchy/netshell ]; then
    wait
    exit 0
fi
$BB tcpsvd -E 0 5001 /bin/sh -c 'read -r f; cat > "$f"; echo "saved $f $(stat -c %s "$f")"' &
exec $BB tcpsvd -E 0 5000 /bin/sh -c 'exec /bin/bash 2>&1'
