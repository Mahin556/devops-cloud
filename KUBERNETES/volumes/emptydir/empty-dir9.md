* **Example: App Using In-Memory Cache (emptyDir.medium: Memory)**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: app-with-cache
  spec:
    containers:
      - name: my-app
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Using in-memory cache...";
            echo "Caching data..." > /cache/data.txt;
            sleep 3600;   # simulate long-running app
        volumeMounts:
          - name: cache-volume
            mountPath: /cache
            # app writes & reads cached data here

    volumes:
      - name: cache-volume
        emptyDir:
          medium: "Memory"     # Store data in RAM (tmpfs)
          sizeLimit: "1Gi"     # Optional limit
  ```
* Common scenarios:
  * Caching frequently accessed files
  * Temporary computation results
  * ML model intermediate outputs
  * Build or compilation caches
  * Web server or API response cache
  * Sorting, indexing, or buffering workloads
* `emptyDir.medium: Memory:` stored in RAM — very fast, like tmpfs
  * Best for high-performance workloads
  * Data disappears if Pod is deleted or node reboots