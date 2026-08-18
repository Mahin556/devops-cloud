# CronJob With `backoffLimit`

Remember that a CronJob creates a **Job**, and the Job has its own retry behavior.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: retry-cronjob

spec:
  schedule: "*/10 * * * *"

  jobTemplate:
    spec:
      backoffLimit: 3

      template:
        spec:
          containers:
            - name: worker
              image: busybox
              command:
                - sh
                - -c
                - |
                  echo "Task failed"
                  exit 1

          restartPolicy: Never
```

Flow:

```text
CronJob
   ↓
Job
   ↓
Pod-1 → Failed
   ↓
Job retry
   ↓
Pod-2 → Failed
   ↓
Job retry
   ↓
Pod-3 → Failed
   ↓
...
   ↓
Job eventually Failed
```

Notice:

```text
CronJob
    ↓
creates Job
    ↓
Job controls Pod execution/retries
```
