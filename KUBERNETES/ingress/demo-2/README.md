# Install MetallB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```

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

### Verify MetallB Installation
```bash
kubectl -n metallb-system get pods
kubectl api-resources| grep metallb
```

### Create IP Pool
```bash
kubectl -n metallb-system apply -f pool-1.yml
```

### Create L2Advertisement
```bash
kubectl -n metallb-system apply -f l2advertisement.yml
```

### Deploy Test Application
```bash
kubectl -n default apply -f deployment.yaml
```

### Verify MetallB assigned an IP address
```bash
kubectl -n default get pods
kubectl -n default get services
```

### Create an Ingress for the Test Applications
```bash
kubectl -n default apply -f web-app-ingress.yml
kubectl -n default get ingress
```