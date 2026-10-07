## Headless Service
```
kubectl create -f statefulset.yaml
kubectl apply -f svc.yaml
```
Check 
`kubectl exec -it postgres-0 -- psql -U postgres`