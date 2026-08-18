# CronJob With `OnFailure`

You can use:

```yaml
restartPolicy: OnFailure
```

inside the Job template.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: onfailure-cronjob

spec:
  schedule: "*/10 * * * *"

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
                  echo "Running..."
                  exit 1

          restartPolicy: OnFailure
```

Here:

```text
Container fails
      ↓
Kubelet restarts container
      ↓
Same Pod
```

This is different from:

```yaml
restartPolicy: Never
```

where:

```text
Container fails
      ↓
Pod fails
      ↓
Job Controller creates replacement Pod
```
