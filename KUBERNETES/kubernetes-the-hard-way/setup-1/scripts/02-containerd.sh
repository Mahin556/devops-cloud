CONTAINERD_VERSION=2.3.3
RUNC_VERSION=v1.5.1
NERDCTL_VERSION=2.3.5
CNI_PLUGINS_VERSION=v1.9.1

curl -fsSLO "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION?}/containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"
sudo tar xzvofC "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz" /usr/local
sudo tar -tzf "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"
sudo rm "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"

sudo wget -P /etc/systemd/system/ "https://raw.githubusercontent.com/containerd/containerd/v${CONTAINERD_VERSION?}/containerd.service"

curl -fsSLO "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION?}/runc.amd64"
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

curl -fsSLO "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION?}/nerdctl-${NERDCTL_VERSION?}-linux-amd64.tar.gz"
tar xzvof "nerdctl-${NERDCTL_VERSION?}-linux-amd64.tar.gz"
sudo install -m 755 nerdctl /usr/local/bin
nerdctl completion bash | sudo tee /etc/bash_completion.d/nerdctl

sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
cat /etc/containerd/config.toml | grep -i SystemdCgroup

curl -fsSLO "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION?}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION?}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar xzvofC "cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION?}.tgz" /opt/cni/bin

sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd --no-pager


