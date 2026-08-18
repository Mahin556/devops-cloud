# CronJob With `suspend`

You can temporarily stop the schedule:

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: maintenance-job

spec:
  schedule: "0 2 * * *"

  suspend: true

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: maintenance
              image: busybox
              command:
                - sh
                - -c
                - echo "Maintenance running"

          restartPolicy: Never
```

Because:

```yaml
suspend: true
```

the CronJob won't create new Jobs.

To resume:

```bash
kubectl patch cronjob maintenance-job \
  -p '{"spec":{"suspend":false}}'
```