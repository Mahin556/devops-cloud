```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-a
spec:
  ingressClassName: nginx
  rules:
  - host: service-a.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Prefix
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
spec:
  ingressClassName: nginx
  rules:
  - host: service-b.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-a
spec:
  ingressClassName: nginx
  rules:
  - host: service-a.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Prefix
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
spec:
  ingressClassName: nginx
  rules:
  - host: service-b.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Exact
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-ab-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: service-a.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-a
            port:
              number: 80
  - host: service-b.mahinraza.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```