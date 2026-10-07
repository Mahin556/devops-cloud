![alt text](image.png)

```bash
curl -LO https://cert-manager.io/public-keys/cert-manager-keyring-2021-09-20-1020CF3C033D4F35BAE1C19E1226061C665DF13E.gpg

helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.2 \
  --namespace cert-manager \
  --create-namespace \
  --verify \
  --keyring ./cert-manager-keyring-2021-09-20-1020CF3C033D4F35BAE1C19E1226061C665DF13E.gpg \
  --set crds.enabled=true \
  --set config.gatewayAPI.enabled=true

``

## These are the steps for self signed certificates.

```

openssl req -x509 -nodes -days 365 -newkey rsa:2048     -out self-signed-tls.crt      -keyout self-signed-tls.key      -subj "/CN=14e7bb11-b41f-4e4b-a177-dd97670a0183.k8s.civo.com/O=self-signed-tls"

```

### Create Kubernetes secret

```
kubectl create secret tls self-signed-tls --key self-signed-tls.key --cert self-signed-tls.crt

```

### Create Deployment and service

```
kubectl create deployment demo --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment demo --port=8080
```

###
Create ingress, make sure you have ingress controller already installed

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-ingress
spec:
  tls:
  - hosts:
    - xyz.com # Replace with your cluster DNS name
    secretName: self-signed-tls
  rules:
  - host: xyz.com # Replace with your cluster DNS name
    http:
      paths:
      - backend:
          service:
            name: demo
            port:
              number: 8080
        path: /demo
        pathType: Prefix 
```

### Check by hitting the URL
curl -v -k https://xyz.com/demo