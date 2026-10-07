```bash
kubectl apply -f ./KUBERNETES/ingress/example-applications/2/service.yaml

kubectl apply -f -<<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-ingress
  annotations:
    nginx.ingress.kubernetes.io/app-root: /home   # redirect host root / to /home - client side redirection
spec:
  ingressClassName: nginx
  rules:
  - host: my-services.mahinraza.online
    http:
      paths:
      # NEW: path for /home to serve the redirected root
      - path: /home #we keep /home here to match those redirected requested
        pathType: Prefix
        backend:
          service:
            name: myservice-svc      
            port:
              number: 80
EOF
```