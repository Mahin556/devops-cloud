# Run Every Hour

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: hourly-job

spec:
  schedule: "0 * * * *"

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: hourly-task
              image: busybox
              command:
                - sh
                - -c
                - echo "Hourly job running"; date

          restartPolicy: Never
```

Schedule:

```text
0 * * * *
```

Means:

```text
Every hour at minute 0
```

Example:

```text
01:00
02:00
03:00
04:00
...
```