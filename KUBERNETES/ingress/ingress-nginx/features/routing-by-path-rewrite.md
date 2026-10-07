```bash
kubectl apply -f -<<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-a
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: my-services.mahinraza.online
    http:
      paths:
      - path: /service-a(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-a
            port:
              number: 80
      - path: /service-b(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```