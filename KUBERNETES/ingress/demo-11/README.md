# Install MetallB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml
```
```bash
k apply -f -<<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.0.120-172.18.0.130
EOF

k apply -f -<<EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF

---

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

---

```bash
kubectl create cm login-app-config --from-file=login-app-nginx.conf --from-file=index.html=login-service-index.html
kubectl create cm payment-app-config --from-file=payment-app-nginx.conf --from-file=index.html=payment-service-index.html
kubectl create cm checkout-app-config --from-file=checkout-app-nginx.conf --from-file=index.html=checkout-service-index.html
```

OR 

```bash
kubectl apply -f cm.yaml
```

---

```bash
k apply -f menifest.yaml
k apply -f ingress.yaml
```

---

```bash
INGRESS_LB_IP=$(k get svc -n ingress-nginx ingress-nginx-controller -ojsonpath='{.status.loadBalancer.ingress[0].ip}')

echo -e "$INGRESS_LB_IP login-app.service.com login-app\n$INGRESS_LB_IP payment-app.service.com payment-app\n$INGRESS_LB_IP checkout-app.service.com checkout-app" >> /etc/hosts
```

---

```bash
curl login-app.service.com
curl login-app.service.com/
curl login-app.service.com/welcome
curl login-app.service.com/welcome/
curl login-app.service.com/welcome/index.html
curl login-app.service.com/endpoint
curl login-app.service.com/endpoint/

curl payment-app.service.com
curl payment-app.service.com/
curl payment-app.service.com/welcome #301
curl payment-app.service.com/welcome/
curl payment-app.service.com/welcome/index.html
curl payment-app.service.com/endpoint
curl payment-app.service.com/endpoint/

curl checkout-app.service.com
curl checkout-app.service.com/
curl checkout-app.service.com/welcome #301
curl checkout-app.service.com/welcome/
curl checkout-app.service.com/welcome/index.html
curl checkout-app.service.com/endpoint
curl checkout-app.service.com/endpoint/
```