KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-scheduler"

sudo install -m 755 kube-scheduler /usr/local/bin

sudo wget -O /etc/systemd/system/kube-scheduler.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/03-kube-scheduler/__static__/kube-scheduler.service?v=1777378795

cd /etc/kubernetes/pki

sudo openssl genrsa -out scheduler.key 2048
sudo openssl req -new -key scheduler.key -out scheduler.csr -subj "/CN=system:kube-scheduler"
sudo openssl x509 -req -in scheduler.csr -out scheduler.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365

sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --client-certificate=/etc/kubernetes/pki/scheduler.crt \
    --client-key=/etc/kubernetes/pki/scheduler.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/scheduler.conf

sudo systemctl daemon-reload
sudo systemctl enable --now kube-scheduler

