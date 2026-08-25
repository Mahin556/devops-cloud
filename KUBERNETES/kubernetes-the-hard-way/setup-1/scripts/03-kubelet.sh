KUBE_VERSION=v1.34.0
CRICTL_VERSION=v1.34.0
KUBELETCTL_VERSION=v1.13

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kubelet"
sudo install -m 755 kubelet /usr/local/bin
sudo wget -O /etc/systemd/system/kubelet.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/02-worker-node/02-kubelet/__static__/kubelet.service?v=1777378794
sudo mkdir -p /var/lib/kubelet/config.d

cat << EOF > /var/lib/kubelet/config.d/99-cri.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
cgroupDriver: systemd
EOF

cat << EOF > /var/lib/kubelet/config.d/70-authnz.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false

authorization:
  mode: AlwaysAllow
EOF

sudo mkdir -p /etc/kubernetes/manifests
cat << EOF > /var/lib/kubelet/config.d/50-static-pods.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

staticPodPath: /etc/kubernetes/manifests
EOF

curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION?}/crictl-${CRICTL_VERSION?}-linux-amd64.tar.gz"
sudo tar xzvof "crictl-${CRICTL_VERSION?}-linux-amd64.tar.gz" -C /usr/local/bin
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF

curl -fsSLO "https://github.com/cyberark/kubeletctl/releases/download/${KUBELETCTL_VERSION?}/kubeletctl_linux_amd64"
sudo install -m 755 kubeletctl_linux_amd64 /usr/local/bin/kubeletctl

sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
sudo systemctl status kubelet --no-pager

kubeletctl configz | jq

