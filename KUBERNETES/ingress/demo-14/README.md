```bash
# Get the Ingress controller external address
INGRESS_ADDRESS=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}{.status.loadBalancer.ingress[0].hostname}')

# Test each path
curl -H "Host: myapp.example.com" http://$INGRESS_ADDRESS/
# Expected: Hello from Frontend

curl -H "Host: myapp.example.com" http://$INGRESS_ADDRESS/api/
# Expected: Hello from API service

curl -H "Host: myapp.example.com" http://$INGRESS_ADDRESS/docs/
# Expected: Hello from Docs service

# Check the generated Nginx configuration
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -B2 -A10 "location /api"
```