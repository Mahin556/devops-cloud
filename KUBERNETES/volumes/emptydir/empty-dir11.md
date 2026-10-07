* **Example: App Writes Intermediate Files to emptyDir → Final Output Saved to PVC**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: app-with-scratchpad
  spec:
    containers:
      - name: processor
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Generating temporary files...";
            echo "temp-data" > /scratch/tmp1.txt;

            echo "Processing data...";
            cat /scratch/tmp1.txt | tr a-z A-Z > /output/final-result.txt;

            echo "Done! Final output saved to PVC.";
            sleep 3600;
        volumeMounts:
          - name: scratchpad
            mountPath: /scratch       # temporary intermediate data
          - name: final-storage
            mountPath: /output        # persistent storage (PVC)

    volumes:
      - name: scratchpad
        emptyDir: {}                 # ephemeral scratch volume

      - name: final-storage
        persistentVolumeClaim:
          claimName: output-pvc      # persistent output storage
  ```
* App writes logs → sidecar rotates them in emptyDir → only rotated/compressed logs stored to PVC/S3