KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-controller-manager"

sudo install -m 755 kube-controller-manager /usr/local/bin

sudo wget -O /etc/systemd/system/kube-controller-manager.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/04-kube-controller-manager/__static__/kube-controller-manager.service?v=1777378796

cd /etc/kubernetes/pki

sudo openssl genrsa -out controller-manager.key 2048
sudo openssl req -new -key controller-manager.key -out controller-manager.csr -subj "/CN=system:kube-controller-manager"
sudo openssl x509 -req -in controller-manager.csr -out controller-manager.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365

sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --client-certificate=/etc/kubernetes/pki/controller-manager.crt \
    --client-key=/etc/kubernetes/pki/controller-manager.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf

sudo systemctl daemon-reload
sudo systemctl enable --now kube-controller-manager
sudo systemctl status kube-controller-manager --no-pager

