### Sequential execution

Now:
```
completions: 4
parallelism: 1
```

means:
```
Pod-1
  ↓
Completed
  ↓
Pod-2
  ↓
Completed
  ↓
Pod-3
  ↓
Completed
  ↓
Pod-4
  ↓
Completed
  ↓
Job Complete
```

Only one Pod runs at a time.

Example:
```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: sequential-job
spec:
  completions: 4
  parallelism: 1
  template:
    spec:
      containers:
        - name: worker
          image: busybox
          command:
            - sh
            - -c
            - echo "Processing"; sleep 5
      restartPolicy: Never
EOF
```