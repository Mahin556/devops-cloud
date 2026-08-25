```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443 --address=0.0.0.0

kubectl apply -f 01-v1-deployment.yaml -f 02-v1-service.yaml -f 03-v1-ingress.yaml

kubectl apply -f 04-v2-deployment.yaml -f 05-v2-service.yaml -f 06-v2-canary-ingress.yaml

while sleep 0.5;do curl -H "Host: blog.example.com" http://localhost:8080/; echo; done
```