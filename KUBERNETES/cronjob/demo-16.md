# Complete production-style example

This combines the major concepts:

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: production-backup

spec:
  # Run every day at 2:00 AM
  schedule: "0 2 * * *"

  # Interpret schedule using India time
  timeZone: "Asia/Kolkata"

  # Don't allow another backup while one is running
  concurrencyPolicy: Forbid

  # CronJob is active
  suspend: false

  # Keep recent Job history for troubleshooting
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3

  # Job definition
  jobTemplate:
    spec:

      # Retry failed Job attempts
      backoffLimit: 3

      # Delete completed Job after 10 minutes
      ttlSecondsAfterFinished: 600

      template:
        spec:

          containers:
            - name: backup
              image: my-backup:v1

              command:
                - /bin/sh
                - -c
                - |
                  echo "Backup started"
                  date

                  /app/backup.sh

                  echo "Backup completed"
                  date

          # Job Pods cannot use restartPolicy: Always
          restartPolicy: Never
```

### Complete flow

```text
                    CronJob
                       │
                       │ 02:00 IST
                       ▼
                     Job-1
                       │
                       ▼
                     Pod-1
                       │
                       ▼
                  Backup container
                       │
              ┌────────┴────────┐
              │                 │
          Success             Failure
              │                 │
              ▼                 ▼
        Job Complete       Job retries
                                │
                         backoffLimit: 3
                                │
                                ▼
                         Eventually Success
                              OR
                           Job Failed
```

And after completion:

```text
Job finished
     ↓
TTL = 600 seconds
     ↓
Job eligible for cleanup
```

### The core distinction to memorize

```text
CronJob
  = WHEN should the task run?

Job
  = HOW should that execution be managed?

Pod
  = WHERE does the task execute?

restartPolicy
  = What should kubelet do when the container exits?

concurrencyPolicy
  = What should happen if the next scheduled execution
    arrives while the previous Job is still running?
```

That's the cleanest mental model for CronJobs in Kubernetes.
