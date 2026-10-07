* **Example: App Stages Data in emptyDir → Sidecar Uploads to S3**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: backup-staging-pod
  spec:
    containers:
      - name: app
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Creating backup files...";
            echo "Backup content at $(date)" > /staging/backup-$(date +%s).txt;
            echo "Backup done. Waiting..."
            sleep 3600;
        volumeMounts:
          - name: staging-area
            mountPath: /staging
        # App writes data to /staging (emptyDir)

      - name: uploader
        image: amazon/aws-cli
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Uploader started...";
            while true; do
              for file in /data/*; do
                if [ -f "$file" ]; then
                  echo "Uploading $file to S3...";
                  # Replace bucket name with your actual bucket
                  aws s3 cp "$file" s3://my-bucket/backups/;
                  echo "Uploaded. Removing local file.";
                  rm -f "$file";
                fi
              done
              sleep 10;
            done
        volumeMounts:
          - name: staging-area
            mountPath: /data
        # Sidecar reads from same emptyDir and uploads to S3

    volumes:
      - name: staging-area
        emptyDir: {}   # Temporary staging area
  ```