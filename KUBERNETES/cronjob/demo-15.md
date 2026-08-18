# Real-world Report Generation

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: daily-report

spec:
  schedule: "30 8 * * *"

  timeZone: "Asia/Kolkata"

  concurrencyPolicy: Forbid

  jobTemplate:
    spec:
      backoffLimit: 3

      template:
        spec:
          containers:
            - name: report-generator
              image: my-report-app:v1

              env:
                - name: ENVIRONMENT
                  value: production

              command:
                - /app/generate-report

          restartPolicy: Never
```

Runs:

```text
Every day at 08:30 AM IST
```

If report generation takes too long:

```text
Forbid
   ↓
Don't start another report until
the previous one is finished.
```