# `concurrencyPolicy: Forbid`

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: forbid-concurrent

spec:
  schedule: "*/5 * * * *"

  concurrencyPolicy: Forbid

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

Behavior:

```text
10:00 → Job-1 starts
10:05 → skipped
10:10 → skipped
10:15 → Job-1 finishes
10:20 → Job-2 starts
```
