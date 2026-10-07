* Use container memory limit to bound tmpfs (works without sizeLimit)
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: tmpfs-by-container-limit
  spec:
    containers:
    - name: app
      image: busybox
      resources:
        limits:
          memory: 2Gi           # tmpfs will not exceed this for the container
      command: ["sh","-c","sleep 3600"]
      volumeMounts:
      - name: ram-cache
        mountPath: /cache
    volumes:
    - name: ram-cache
      emptyDir:
        medium: "Memory"
  ```