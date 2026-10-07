```yaml
cat << EOF > kind-flannel-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /lib/modules
    containerPath: /lib/modules
    readOnly: true
- role: worker
- role: worker
EOF
```
```bash
kind delete cluster --name flannel-cluster

# Load the module immediately
sudo modprobe br_netfilter

# Ensure it persists after reboot
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/br_netfilter.conf

# Run these commands to tell the system to let bridge traffic pass through iptables:
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo sysctl net.bridge.bridge-nf-call-ip6tables=1

# To make these sysctl settings permanent, save them to a configuration file:
sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system


kind create cluster --name flannel-cluster --config kind-flannel-config.yaml
```
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

kubectl get all -n kube-flannel

kubectl rollout restart ds kube-flannel-ds -n kube-flannel
```