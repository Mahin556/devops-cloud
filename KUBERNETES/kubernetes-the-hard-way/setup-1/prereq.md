### Disabling SWAP
```bash
sudo swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab
```

### Loading Kernel Modules
```bash
tee /etc/modules-load.d/modules.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```