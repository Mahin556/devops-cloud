### ResourceQuota (Validating Controller)

ResourceQuota prevents resource overconsumption - like having a spending limit on your credit card.

**Step 1**: Create a namespace with a resource quota

```yaml
# Create file: resource-quota-demo.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: quota-demo
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: quota-demo
spec:
  hard:
    requests.cpu: "1"
    requests.memory: 1Gi
    limits.cpu: "2"
    limits.memory: 2Gi
    pods: "4"
```

**Step 2**: Apply the configuration

```bash
kubectl apply -f resource-quota-demo.yaml
```

**Step 3**: Try to create a pod that exceeds the quota

```yaml
# Create file: big-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: big-pod
  namespace: quota-demo
spec:
  containers:
  - name: big-container
    image: nginx
    resources:
      requests:
        memory: "2Gi"  # This exceeds our quota!
        cpu: "1"
```

**Step 4**: Apply and observe the error

```bash
kubectl apply -f big-pod.yaml
```

**Question for Students**: What error did you get? Why did the admission controller reject this pod?