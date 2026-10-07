### Foreground → delete Replicasets, then its dependents.
```bash
kubectl proxy --port=8080

curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/replicasets/nginx-rs' \
     -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Foreground"}' \
     -H "Content-Type: application/json"
```

### Background → delete Replicasets immediately; dependents are cleaned up afterward.
```bash
curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/replicasets/nginx-rs' \
     -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Background"}' \
     -H "Content-Type: application/json"
```

### Orphan → delete Replicasets but leave its dependents behind
```bash
curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/replicasets/nginx-rs' \
     -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Orphan"}' \
     -H "Content-Type: application/json"
```

---

### Foreground → delete Deployment, then its dependents.
```bash
curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/deployments/nginx' \
  -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Foreground"}' \
  -H "Content-Type: application/json"
```

### Background → delete Deployment immediately; dependents are cleaned up afterward.
```bash
curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/deployments/nginx' \
  -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Background"}' \
  -H "Content-Type: application/json"
```

### Orphan → delete Deployment but leave its dependents behind.
```bash
curl -X DELETE 'http://localhost:8080/apis/apps/v1/namespaces/default/deployments/nginx' \
  -d '{"kind":"DeleteOptions","apiVersion":"v1","propagationPolicy":"Orphan"}' \
  -H "Content-Type: application/json"
```
