```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443 --address=0.0.0.0

curl -H "Host: app.example.com" http://localhost:8080/login
```