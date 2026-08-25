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

kubectl exec frontend -- curl backend
kubectl exec backend -- curl frontend

kubectl exec frontend -- curl ${BACKEND_IP}
kubectl exec backend -- curl ${FRONTEND_IP}
```