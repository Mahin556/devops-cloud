### `kubectl proxy` commands

**1. Start proxy on default port `8001`:**

```bash
kubectl proxy
```

**2. Start on a custom port:**

```bash
kubectl proxy --port=8080
```

**3. Check API versions:**

```bash
curl http://localhost:8001/api
```

**4. Check API server root:**

```bash
curl http://localhost:8001/
```

**5. List API resources:**

```bash
curl http://localhost:8001/api/v1
```

**6. List Pods in `default` namespace:**

```bash
curl http://localhost:8001/api/v1/namespaces/default/pods
```

**7. List Pods in another namespace:**

```bash
curl http://localhost:8001/api/v1/namespaces/kube-system/pods
```

**8. List Services:**

```bash
curl http://localhost:8001/api/v1/namespaces/default/services
```

**9. List Nodes:**

```bash
curl http://localhost:8001/api/v1/nodes
```

**10. Get a specific Pod:**

```bash
curl http://localhost:8001/api/v1/namespaces/default/pods/<pod-name>
```

**11. Get a specific Service:**

```bash
curl http://localhost:8001/api/v1/namespaces/default/services/<service-name>
```

**12. Access a Service through the API proxy:**

```bash
curl http://localhost:8001/api/v1/namespaces/default/services/<service-name>/proxy/
```

**13. Run proxy in background:**

```bash
kubectl proxy &
```

**14. Stop the background proxy:**

```bash
pkill -f "kubectl proxy"
```

### Useful troubleshooting

Check whether port `8001` is listening:

```bash
ss -lntp | grep 8001
```

Check the proxy endpoint:

```bash
curl http://127.0.0.1:8001/version
```

Check Kubernetes API directly with `kubectl`:

```bash
kubectl cluster-info
```

### Quick lab

Run these in two terminals.

**Terminal 1:**

```bash
kubectl proxy
```

**Terminal 2:**

```bash
curl http://localhost:8001/version
curl http://localhost:8001/api
curl http://localhost:8001/api/v1/nodes
curl http://localhost:8001/api/v1/namespaces/default/pods
```

The key pattern to remember is:

```text
curl
  ↓
localhost:8001
  ↓
kubectl proxy
  ↓
Kubernetes API Server :6443
```
