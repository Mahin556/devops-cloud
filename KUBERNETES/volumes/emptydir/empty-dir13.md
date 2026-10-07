* **Use emptyDir as /dev/shm shared memory for applications that require fast inter-process communication (IPC), such as:**
  * PostgreSQL
  * Chrome / Chromium
  * Machine learning frameworks (PyTorch / TensorFlow)
  * Video processing
  * High-performance apps that need large shared memory
  * **Example: Mount emptyDir (RAM) as /dev/shm**
    * By default, Kubernetes gives a very small /dev/shm (64MB).
    * Using an emptyDir with medium: Memory gives you large, fast shared memory.

  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: shm-enabled-app
  spec:
    containers:
      - name: app
        image: postgres:14
        # PostgreSQL benefits from a larger /dev/shm
        volumeMounts:
          - name: dshm
            mountPath: /dev/shm

    volumes:
      - name: dshm
        emptyDir:
          medium: "Memory"
          sizeLimit: "1Gi"   # optional limit
  ```