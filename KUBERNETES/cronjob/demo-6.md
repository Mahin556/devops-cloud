# CronJob With `concurrencyPolicy: Allow`

This is the default.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: allow-concurrent

spec:
  schedule: "*/5 * * * *"

  concurrencyPolicy: Allow

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: worker
              image: busybox
              command:
                - sh
                - -c
                - |
                  echo "Started"
                  sleep 600
                  echo "Finished"

          restartPolicy: Never
```

The Job takes 10 minutes, but the CronJob runs every 5 minutes.

Therefore:

```text
10:00 → Job-1 starts
10:05 → Job-2 starts
10:10 → Job-3 starts
10:15 → Job-4 starts
```

Multiple Jobs can run simultaneously.