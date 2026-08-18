# Run Every 5 Minutes

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: five-minute-job

spec:
  schedule: "*/5 * * * *"

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
                  echo "Job started"
                  date
                  echo "Job finished"

          restartPolicy: Never
```

Cron schedule:

```text
*/5 * * * *
│
└── Every 5 minutes
```

Runs at:

```text
10:00
10:05
10:10
10:15
10:20
...
```
