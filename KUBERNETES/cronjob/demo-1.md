# Basic CronJob — Run Every Minute

The simplest example.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: hello-cronjob

spec:
  # Run every minute
  schedule: "* * * * *"

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: hello
              image: busybox
              command:
                - sh
                - -c
                - |
                  echo "Hello from CronJob!"
                  date

          restartPolicy: Never
```

### Flow

```text
Every minute
    ↓
CronJob
    ↓
Job created
    ↓
Pod created
    ↓
echo + date
    ↓
Pod Completed
```

Check:

```bash
kubectl get cronjob
kubectl get jobs
kubectl get pods
```