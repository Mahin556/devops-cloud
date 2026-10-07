* **Multiple containers in the same Pod can **share files** via a common `emptyDir`**
    ```yaml
    containers:
    - name: producer
      image: busybox
      command: ["/bin/sh", "-c", "echo 'data' > /data/file"]
      volumeMounts:
      - name: shared
        mountPath: /data
    - name: consumer
      image: busybox
      command: ["/bin/sh", "-c", "cat /data/file"]
      volumeMounts:
      - name: shared
        mountPath: /data
    volumes:
    - name: shared
      emptyDir: {}
    ```