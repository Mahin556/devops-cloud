### Update resource limits:

```bash
kubectl set resources deployment/nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi
```

**Output:**

```
deployment.apps/nginx-deployment resource requirements updated
```
---

## 8. Resource Quotas

### ResourceQuota (namespace-level budget)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "10"
    limits.memory: "16Gi"
```

Restricts total CPU/memory requests & limits in a namespace.

---

### LimitRange (default requests/limits for Pods)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: dev
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "1Gi"
    defaultRequest:
      cpu: "200m"
      memory: "512Mi"
    type: Container
```

🔹 Ensures Pods in `dev` namespace get defaults if not specified.

---

## 9. Best Practices

✅ Always set **requests** for critical workloads → ensures they get scheduled properly.
✅ Always set **limits** to prevent “noisy neighbor” problems.
✅ For latency-sensitive apps → set `requests == limits` (Guaranteed QoS).
✅ Use **ResourceQuota + LimitRange** at namespace level to enforce fairness.
✅ Monitor with `kubectl top` + Prometheus + Grafana.
✅ For autoscaling → configure **HPA/VPA** (Horizontal/Vertical Pod Autoscaler).

---

## 10. Real-World Scenarios

* **Web App**: CPU bursts needed → small `request`, bigger `limit`.
* **Batch Job**: May use max available → set high `limit`, moderate `request`.
* **Database**: Needs stability → set `request == limit`.
* **Dev workloads**: Small requests, soft limits → prevents cluster starvation.

---

⚡ In short:

* **Requests = minimum guaranteed**
* **Limits = maximum allowed**
* Together, they control **scheduling, performance, and cluster stability**.


### References
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/