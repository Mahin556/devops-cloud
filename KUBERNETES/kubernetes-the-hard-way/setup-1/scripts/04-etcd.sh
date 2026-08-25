ETCD_VERSION=v3.6.4

curl -fsSLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION?}/etcd-${ETCD_VERSION?}-linux-amd64.tar.gz"
tar xzvof "etcd-${ETCD_VERSION?}-linux-amd64.tar.gz"
sudo install -m 755 "etcd-${ETCD_VERSION?}-linux-amd64"/{etcd,etcdctl,etcdutl} /usr/local/bin
etcdctl completion bash | sudo tee /etc/bash_completion.d/etcdctl

sudo adduser \
    --system \
    --group \
    --disabled-login \
    --disabled-password \
    --home /var/lib/etcd \
    etcd

sudo wget -O /etc/systemd/system/etcd.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/01-etcd/__static__/etcd.service?v=1777378794

sudo mkdir -p /etc/etcd/pki
cd /etc/etcd/pki

sudo openssl genrsa -out ca.key 4096
sudo openssl req -x509 -new -nodes -key ca.key -out ca.crt -subj "/CN=etcd" -sha256 -days 3650

cat <<EOF | sudo tee server.cnf
[ req ]

default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
prompt             = no

[ req_distinguished_name ]

CN = server

[ req_ext ]

subjectAltName = @alt_names

[ alt_names ]

DNS.1 = localhost
DNS.2 = $(hostname)

IP.1 = 127.0.0.1
IP.2 = ::1
EOF

i=3
for ip in $(ip -o -4 addr show | awk '$2 != "lo" {split($4,a,"/"); print a[1]}'); do
    echo "IP.$i = $ip" | sudo tee -a server.cnf
    i=$((i+1))
done

sudo openssl genrsa -out server.key 2048
sudo openssl req -new -key server.key -out server.csr -config server.cnf
sudo openssl x509 -req -in server.csr -out server.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365 -extfile server.cnf -extensions req_ext

sudo openssl genrsa -out client.key 2048
sudo openssl req -new -key client.key -out client.csr -subj "/CN=etcd/O=etcd"
sudo openssl x509 -req -in client.csr -out client.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365

sudo chown -R etcd:etcd .

sudo chmod 644 client.key

cd

cat <<EOF | sudo tee -a /etc/default/etcd

ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379

ETCD_CLIENT_CERT_AUTH=true
ETCD_CERT_FILE=/etc/etcd/pki/server.crt
ETCD_KEY_FILE=/etc/etcd/pki/server.key
ETCD_TRUSTED_CA_FILE=/etc/etcd/pki/ca.crt

ETCD_NAME=$(hostname)
ETCD_ADVERTISE_CLIENT_URLS=https://$(hostname):2379

EOF

cat <<EOF | tee -a "$HOME/.bashrc" "$HOME/.profile"

export ETCDCTL_CACERT=/etc/etcd/pki/ca.crt
export ETCDCTL_CERT=/etc/etcd/pki/client.crt
export ETCDCTL_KEY=/etc/etcd/pki/client.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now etcd

bash --login -c "etcdctl endpoint health"
