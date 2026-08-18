# CronJob With TTL Cleanup

You can combine CronJob history management with Job TTL.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: cleanup-example

spec:
  schedule: "*/10 * * * *"

  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1

  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 300

      template:
        spec:
          containers:
            - name: cleanup
              image: busybox
              command:
                - sh
                - -c
                - echo "Cleanup completed"

          restartPolicy: Never
```

Here:

```text
CronJob
   |
   ├── Job-1
   ├── Job-2
   ├── Job-3
   └── Job-4
```

Finished Jobs can be cleaned up through the TTL mechanism, while the CronJob also maintains its successful/failed Job history limits.
