# CronJob With History Limits

By default:

```yaml
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1
```

You can customize them:

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: history-example

spec:
  schedule: "*/10 * * * *"

  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 3

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
                - echo "Processing"

          restartPolicy: Never
```

Now Kubernetes keeps approximately:

```text
5 successful Jobs
3 failed Jobs
```

This is useful when you want more historical Job information for troubleshooting.