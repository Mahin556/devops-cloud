### LimitRanger (Mutating Controller)

LimitRanger automatically adds resource limits - like a helpful assistant that fills out forms for you.

**Step 1**: Create a LimitRange

```yaml
# Create file: limit-range-demo.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
  namespace: quota-demo
spec:
  limits:
  - default:
      memory: "512Mi"
      cpu: "200m"
    defaultRequest:
      memory: "256Mi"
      cpu: "100m"
    type: Container
```

**Step 2**: Apply the LimitRange

```bash
kubectl apply -f limit-range-demo.yaml
```

**Step 3**: Create a pod without specifying resources

```yaml
# Create file: simple-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-pod
  namespace: quota-demo
spec:
  containers:
  - name: simple-container
    image: nginx
```

**Step 4**: Apply and check the pod

```bash
kubectl apply -f simple-pod.yaml
kubectl get pod simple-pod -n quota-demo -o yaml | grep -A 10 resources
```

**Question for Students**: What resources were automatically added to your pod?