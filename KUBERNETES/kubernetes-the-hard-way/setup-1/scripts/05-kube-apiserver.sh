KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-apiserver"
sudo install -m 755 kube-apiserver /usr/local/bin

sudo mkdir -p /etc/kubernetes/pki
cd /etc/kubernetes/pki
sudo openssl genrsa -out sa.key 2048
sudo openssl rsa -in sa.key -pubout -out sa.pub

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kubectl"
sudo install -m 755 kubectl /usr/local/bin
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl

echo "iximiuz,admin,admin,system:masters" | sudo tee /etc/kubernetes/tokens.csv

cd /etc/kubernetes/pki

sudo openssl genrsa -out ca.key 2048
sudo openssl req -x509 -new -nodes -key ca.key -out ca.crt \
  -subj "/CN=kubernetes" -sha256 -days 36

cat <<EOF | sudo tee apiserver.cnf

[ req ]

default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]

CN = kube-apiserver

[ req_ext ]

subjectAltName = @alt_names

[ alt_names ]

DNS.1 = localhost
DNS.2 = kubernetes
DNS.3 = kubernetes.default
DNS.4 = kubernetes.default.svc
DNS.5 = kubernetes.default.svc.cluster.local
DNS.6 = control-plane

IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 10.96.0.1
EOF

i=4
for ip in $(ip -o -4 addr show | awk '$2 != "lo" {split($4,a,"/"); print a[1]}'); do
    echo "IP.$i = $ip" | sudo tee -a apiserver.cnf
    i=$((i+1))
done

sudo openssl genrsa -out apiserver.key 2048
sudo openssl req -new -key apiserver.key -out apiserver.csr -config apiserver.cnf
sudo openssl x509 -req -in apiserver.csr -out apiserver.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365 -extfile apiserver.cnf -extensions req_ext

sudo openssl genrsa -out admin.key 2048
sudo openssl req -new -key admin.key -out admin.csr -subj "/CN=admin/O=system:masters"
sudo openssl x509 -req -in admin.csr -out admin.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365

sudo chmod 644 admin.key

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://kubernetes.io
After=etcd.service
Requires=etcd.service

[Service]
Type=notify

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379 \
    --anonymous-auth=false \
    --token-auth-file=/etc/kubernetes/tokens.csv \
    --authorization-mode=Node,RBAC \
    --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
    --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \
    --client-ca-file=/etc/kubernetes/pki/ca.crt

EnvironmentFile=-/etc/default/%p

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now kube-apiserver
sudo systemctl status kube-apiserver --no-pager

kubectl config set-cluster default \
    --insecure-skip-tls-verify \
    --server=https://localhost:6443

kubectl config set-credentials default \
    --token=iximiuz

kubectl config set-context default \
    --cluster=default \
    --user=default

kubectl config use-context default

kubectl cluster-info

curl -f -k -H "Authorization: Bearer iximiuz" https://localhost:6443/api/v1/namespaces

cd

kubectl config set-cluster default \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --server=https://localhost:6443

kubectl config set-credentials default \
    --client-certificate=/etc/kubernetes/pki/admin.crt \
    --client-key=/etc/kubernetes/pki/admin.key \
    --token=""

kubectl config set-context default \
    --cluster=default \
    --user=default

kubectl config use-context default

kubectl cluster-info

curl -f https://127.0.0.1:6443/api/v1/namespaces \
    --cacert /etc/kubernetes/pki/ca.crt \
    --cert /etc/kubernetes/pki/admin.crt \
    --key /etc/kubernetes/pki/admin.key

