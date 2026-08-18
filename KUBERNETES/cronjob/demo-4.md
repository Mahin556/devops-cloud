# Run Every Day at 2 AM

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: daily-backup

spec:
  schedule: "0 2 * * *"

  timeZone: "Asia/Kolkata"

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: busybox
              command:
                - sh
                - -c
                - |
                  echo "Starting daily backup..."
                  date
                  echo "Backup completed successfully"

          restartPolicy: Never
```

This runs:

```text
Every day
     ↓
02:00 AM
     ↓
Asia/Kolkata
```
