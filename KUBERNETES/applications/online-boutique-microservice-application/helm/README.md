```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

sed -i '/args:/a\        - --kubelet-insecure-tls' components.yaml

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace --values ingress-nginx-values.yaml

openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout wildcard.mahinraza.online.key \
  -out wildcard.mahinraza.online.crt \
  -subj "/CN=*.mahinraza.online" \
  -addext "subjectAltName=DNS:*.mahinraza.online,DNS:mahinraza.online"

openssl x509 -in wildcard.mahinraza.online.crt -text -noout

kubectl create secret tls wildcard-mahinraza-online \
  --cert=wildcard.mahinraza.online.crt \
  --key=wildcard.mahinraza.online.key

CHART_VERSION="41.0.2" # traefik version v3.6.0
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm search repo traefik --versions
kubectl create namespace traefik

kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

helm upgrade --install traefik traefik/traefik \
  --version $CHART_VERSION \
  --values values.yaml \
  --namespace traefik \
  --create-namespace



```