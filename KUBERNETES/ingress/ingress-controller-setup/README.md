# Install Ingress
```bash
# Install ingress-nginx Controller using Helm

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo list
helm repo update
helm search repo ingress-nginx --versions
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.15.0

# Verify the controller is running
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```