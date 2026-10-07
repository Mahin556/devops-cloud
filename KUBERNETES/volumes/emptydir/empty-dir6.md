* Fallback (privileged tmpfs mount inside container)
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: tmpfs-privileged
  spec:
    containers:
    - name: app
      image: quay.io/buildah/stable:v1.23.1
      command: ["/bin/sh","-c"]
      args:
        - mkdir -p /var/lib/containers &&
          mount -t tmpfs -o size=1G tmpfs /var/lib/containers &&
          sleep infinity
      securityContext:
        privileged: true
  ```
  ```bash
  kubectl exec -it <pod> -- df -h /cache

  #Test ENOSPC (if limit small):
  kubectl exec -it <pod> -- sh -c "dd if=/dev/zero of=/cache/bigfile bs=1M count=1024" 
  #If above exceeds tmpfs, you’ll get dd: write error: No space left on device.

  kubectl exec -it <pod> -- sh -c "free -h && df -h /cache"
  ```