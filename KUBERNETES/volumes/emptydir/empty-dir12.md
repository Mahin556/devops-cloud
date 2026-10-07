* **Example: CI/CD Build Pod Using emptyDir Workspace**
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: build-pod
  spec:
    containers:
      - name: builder #Builder container->Clones code,Builds it,Produces artifacts
        image: alpine/git
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Cloning repository...";
            git clone https://github.com/example/app.git /workspace/app;

            echo "Building app...";
            cd /workspace/app;
            touch build-output.txt;  # simulate app build

            echo "Build complete. Workspace is temporary.";
            sleep 3600;
        volumeMounts:
          - name: workspace
            mountPath: /workspace

      - name: packager #Packager container (optional sidecar)-->Reads compiled artifacts,Could push them to:(OCI registry,S3,artifact storage)
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo "Packaging artifacts...";
            ls /workspace/app;
            sleep 3600;
        volumeMounts:
          - name: workspace
            mountPath: /workspace
        # Sidecar container sees the same workspace

    volumes:
      - name: workspace
        emptyDir: {}   # Temporary build workspace
  ```

* Example: App Using emptyDir to Preserve State Across Container Restarts
  * Scenario:
    * Container keeps crashing and restarting
    * Pod stays alive
    * emptyDir volume retains temporary files (lock files, progress markers)
    * When container comes back up, it can resume or skip processed work

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crashloop-recovery-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - |
          echo "Starting app...";
          
          # Simulate reading previous state
          if [ -f /state/progress.txt ]; then
            echo "Previous progress: $(cat /state/progress.txt)"
          else
            echo "No previous progress found. Starting fresh."
          fi

          # Simulate processing
          echo "Saving progress..."
          date > /state/progress.txt

          echo "Crashing the container intentionally..."
          exit 1   # This simulates a crash (CrashLoopBackOff)

      volumeMounts:
        - name: recover-state
          mountPath: /state
  volumes:
    - name: recover-state
      emptyDir: {}    # Persists across container restarts
```
* Container restarts
  * The container crashes (exit 1)
  * Kubernetes restarts ONLY the container
  * `emptyDir` survives, so /state/progress.txt is still there
  * The next time the container starts, it sees the previous progress
* Pod restarts
  * If the Pod gets rescheduled or recreated:
  * `emptyDir` is wiped
  * State is lost (by design)