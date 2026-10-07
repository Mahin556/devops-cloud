* **Example: Nginx + Log-Uploader Sidecar Using EmptyDir**
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx-with-sidecar
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - name: shared-logs
          mountPath: /var/log/nginx
          # Nginx will write access.log and error.log here

      - name: log-uploader
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - |
            echo "Starting log uploader...";
            while true; do
            if [ -f /logs/access.log ]; then
                echo "Uploading logs...";  
                # Example upload command (replace as needed)
                cat /logs/access.log;
                # aws s3 cp /logs/access.log s3://mybucket/logs/;
                > /logs/access.log;
            fi
            sleep 10;
            done
        volumeMounts:
        - name: shared-logs
          mountPath: /logs
          # Sidecar reads logs from same shared volume

      volumes:
      - name: shared-logs
        emptyDir: {}
    ```
    * Real-World Variations You Can Use
      * Replace busybox sidecar with:
        * `fluentd`
        * `vector`
        * `logstash`
        * `custom Python uploader`
      * Sync logs to:
        * `S3`
        * `ElasticSearch`
        * `Splunk`
        * `Kafka`