# `concurrencyPolicy: Replace`

This is useful when **only the latest execution matters**.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: replace-job

spec:
  schedule: "*/5 * * * *"

  concurrencyPolicy: Replace

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
                  echo "Processing latest data..."
                  sleep 600

          restartPolicy: Never
```

Behavior:

```text
10:00 → Job-1 starts
10:05 → Job-1 replaced by Job-2
10:10 → Job-2 replaced by Job-3
10:15 → Job-3 replaced by Job-4
```