# Real-world Log Cleanup CronJob

Suppose an application stores temporary files and you want to clean them every night.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: cleanup-temp-files

spec:
  schedule: "0 1 * * *"

  timeZone: "Asia/Kolkata"

  concurrencyPolicy: Forbid

  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3

  jobTemplate:
    spec:
      backoffLimit: 2

      template:
        spec:
          containers:
            - name: cleanup
              image: busybox
              command:
                - sh
                - -c
                - |
                  echo "Starting cleanup..."
                  echo "Deleting temporary files..."
                  echo "Cleanup completed."

          restartPolicy: Never
```

This demonstrates several concepts together:

```text
schedule
    ↓
Every day at 1 AM

timeZone
    ↓
Asia/Kolkata

concurrencyPolicy
    ↓
Don't run two cleanups simultaneously

backoffLimit
    ↓
Retry failed Job

history limits
    ↓
Don't retain unlimited Job history
```