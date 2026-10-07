```bash
helm install traefik traefik/traefik -f values.yaml

kubectl applt -f 01-gateway-class.yaml
kubectl applt -f 02-cluster-issuer.yaml
kubectl applt -f 03-gateway.yaml
kubectl applt -f 04-http-route.yaml

```