```bash
kubectl apply -f ./KUBERNETES/ingress/example-applications/1/service-a.yaml
kubectl apply -f ./KUBERNETES/ingress/example-applications/1/service-b.yaml

kubectl apply -f -<<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-a
  annotations:
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: server-a-secret
    nginx.ingress.kubernetes.io/auth-secret-type: auth-file
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
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-b
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: my-services.mahinraza.online
    http:
      paths:
      - path: /service-b(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```