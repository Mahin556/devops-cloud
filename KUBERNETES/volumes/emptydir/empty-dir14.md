* **Soft Limit vs Hard limit**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: emptydir-size-limit-demo
  spec:
    containers:
      - name: app
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Writing files...";
            dd if=/dev/zero of=/disk-cache/bigfile1 bs=1M count=6000;   # write 6GB
            dd if=/dev/zero of=/ram-cache/bigfile2 bs=1M count=1200;   # write 1.2GB
            sleep 3600

        ## Mount both volumes into the container
        volumeMounts:
          - name: disk-cache
            mountPath: /disk-cache
          - name: ram-cache
            mountPath: /ram-cache

    volumes:

      # --------------------------------------------------------
      # 1️⃣ emptyDir using HOST DISK (medium: "")
      # --------------------------------------------------------
      # ✔ sizeLimit works but is NOT strictly enforced
      # ✔ Kubernetes will TRY to prevent usage above 5Gi
      # ✘ If node runs out of disk → Pod gets EVICTED
      # ✔ Good for temporary files, logs, builds
      #
      # Behavior:
      # - Directory can grow up to ~5Gi (soft limit)
      # - If write exceeds available node storage → Pod eviction
      #
      # Not a hard quota!
      #
      - name: disk-cache
        emptyDir:
          medium: ""          # stored on node filesystem
          sizeLimit: "5Gi"    # soft limit (best-effort)

      # --------------------------------------------------------
      # 2️⃣ emptyDir using RAM (medium: "Memory")
      # --------------------------------------------------------
      # ✔ Uses tmpfs stored in RAM
      # ✔ sizeLimit is STRICTLY enforced by Linux kernel
      # ✔ Writes fail with ENOSPC when exceeding 1Gi
      # ✔ High-speed I/O, great for caches & `/dev/shm`
      #
      # Behavior:
      # - EXACT 1Gi cap enforced
      # - Cannot exceed this limit
      # - Using more RAM may cause OOMKill (container killed)
      #
      # Hard quota!
      #
      - name: ram-cache
        emptyDir:
          medium: "Memory"    # stored in RAM (tmpfs)
          sizeLimit: "1Gi"    # strict hard limit
  ```
* Linux has no per-directory quota
* tmpfs supports _exact_ size limits
