```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout wildcard.mahinraza.online.key \
  -out wildcard.mahinraza.online.crt \
  -subj "/CN=*.mahinraza.online" \
  -addext "subjectAltName=DNS:*.mahinraza.online,DNS:mahinraza.online"

openssl x509 -in wildcard.mahinraza.online.crt -text -noout

kubectl create secret tls wildcard-mahinraza-online \
  --cert=wildcard.mahinraza.online.crt \
  --key=wildcard.mahinraza.online.key
```
```bash
kubectl apply -f -<<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`nginx.mahinraza.online`)
      kind: Rule
      services:
        - name: nginx-svc-blue
          port: 80
  tls:
    secretName: wildcard-mahinraza-online
EOF