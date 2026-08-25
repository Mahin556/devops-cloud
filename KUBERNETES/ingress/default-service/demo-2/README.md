```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443 --address=0.0.0.0

curl -H "Host: app.example.com" http://localhost:8080/login11 # Handle by demo ingress default backend
curl -H "Host: demo.example.com" http://localhost:8080/login # Handle by demo ingress default backemd
curl -H "Host: app1.example.com" http://localhost:8080/login # handle by demo1 ingress default backend
```