# Install MetallB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
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