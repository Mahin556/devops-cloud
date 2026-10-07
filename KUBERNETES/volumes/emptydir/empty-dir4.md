* Memory-backed emptyDir with explicit sizeLimit (K8s ≥1.22)
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: tmpfs-size-demo
  spec:
    containers:
    - name: app
      image: busybox
      command: ["sh","-c","sleep 3600"]
      volumeMounts:
      - name: ram-cache
        mountPath: /cache
    volumes:
    - name: ram-cache
      emptyDir:
        medium: "Memory"
        sizeLimit: "1Gi"        # hard 1Gi tmpfs cap (kernel-enforced)
  ```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
  - image: registry.k8s.io/test-webserver
    name: test-container
    volumeMounts:
    - mountPath: /cache
      name: cache-volume
  volumes:
  - name: cache-volume
    emptyDir:
      sizeLimit: 500Mi
```
---