```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

kubectl get networkpolicy
```
```bash
kubectl run frontend --image=nginx
kubectl run backend --image=nginx

kubectl wait --for=condition=Ready pod -l run=frontend
kubectl wait --for=condition=Ready pod -l run=backend

FRONTEND_IP=$(kubectl get pod frontend -ojsonpath='{.status.podIP}')
BACKEND_IP=$(kubectl get pod backend -ojsonpath='{.status.podIP}')

kubectl exec frontend -- curl backend #FAIL
kubectl exec backend -- curl frontend #FAIL

kubectl exec frontend -- curl ${BACKEND_IP} #FAIL
kubectl exec backend -- curl ${FRONTEND_IP} #FAIL
```
```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-traffic-for-frontend
  namespace: default
spec:
  podSelector: 
    matchLabels:
      run: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          run: backend
EOF

kubectl get networkpolicy

kubectl exec frontend -- curl backend #FAIL
kubectl exec backend -- curl frontend #FAIL

kubectl exec frontend -- curl ${BACKEND_IP} #FAIL
kubectl exec backend -- curl ${FRONTEND_IP} #FAIL

kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-traffic-for-backend
  namespace: default
spec:
  podSelector: 
    matchLabels:
      run: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: frontend
EOF

kubectl get networkpolicy

kubectl exec frontend -- curl backend #FAIL
kubectl exec backend -- curl frontend #FAIL

kubectl exec frontend -- curl ${BACKEND_IP} #WORK
kubectl exec backend -- curl ${FRONTEND_IP} #FAIL
```