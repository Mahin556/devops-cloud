```bash
CLUSTER_NAME=mycluster

kind create clusters --name $CLUSTER_NAME --config config.yaml

kind get clusters

# Build all images (optional, but recommended)
docker compose build

IMAGES=(adservice cartservice checkoutservice redis currencyservice emailservice frontend loadgenerator paymentservice productcatalogservice recommendationservice shippingservice shoppingassistantservice)

docker image pull redis:alpine

for image in "${IMAGES[@]}"; do
  if [ "$image" = "redis" ]; then
    # Redis uses the 'alpine' tag
    kind load docker-image "redis:alpine" --name mycluster
  else
    kind load docker-image "${image}:latest" --name mycluster
  fi
done

for i in "${!IMAGES[@]}"; do
  if [ "${IMAGES[i]}" = "redis" ]; then
    # This condition will never be true because "redis" is not in the array.
    echo "Loading Image $((i+1)): ${IMAGES[i]}"
    kind load docker-image "redis:alpine" --name mycluster
  else
    echo "Loading Image $((i+1)): ${IMAGES[i]}"
    kind load docker-image "${IMAGES[i]}:latest" --name mycluster
  fi
done

# Install cloud-provider-kind
go install sigs.k8s.io/cloud-provider-kind@latest
ls ~/go/bin/cloud-provider-kind

# Make it available system-wide:
sudo install ~/go/bin/cloud-provider-kind /usr/local/bin/cloud-provider-kind
cloud-provider-kind --help
# sudo cloud-provider-kind

cat << EOF > /etc/systemd/system/cloud-provider-kind.service
[Unit]
Description=Cloud Provider Kind Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
# Replace with the exact output from 'which cloud-provider-kind'
ExecStart=/usr/local/bin/cloud-provider-kind
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cloud-provider-kind.service
sudo systemctl status cloud-provider-kind.service
sudo journalctl -u cloud-provider-kind.service -f

# Testing Load Balancer
cat <<'EOF' > app.yaml
kind: Pod
apiVersion: v1
metadata:
  name: foo-app
  labels:
    app: http-echo
spec:
  containers:
  - command:
    - /agnhost
    - serve-hostname
    - --http=true
    - --port=8080
    image: registry.k8s.io/e2e-test-images/agnhost:2.39
    name: foo-app
---
kind: Pod
apiVersion: v1
metadata:
  name: bar-app
  labels:
    app: http-echo
spec:
  containers:
  - command:
    - /agnhost
    - serve-hostname
    - --http=true
    - --port=8080
    image: registry.k8s.io/e2e-test-images/agnhost:2.39
    name: bar-app
---
kind: Service
apiVersion: v1
metadata:
  name: foo-service
spec:
  type: LoadBalancer
  selector:
    app: http-echo
  ports:
  - port: 5678
    targetPort: 8080
EOF

kubectl apply -f app.yaml

kubectl get pods

kubectl get svc foo-service

# Get the external IP:
LB_IP=$(kubectl get svc/foo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $LB_IP

# should output foo and bar on separate lines 
for _ in {1..10}; do
  curl ${LB_IP}:5678
done

# Testing port forwarding
apt install socat -y
socat TCP-LISTEN:80,fork TCP:$LB_IP:5678

```
```bash
kubectl apply -f manifests/
kubectl delete -f manifests/

LB_IP=$(kubectl get svc frontend-external -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $LB_IP

socat TCP-LISTEN:80,fork TCP:$LB_IP:80
```