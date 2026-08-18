```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: parallel-job

spec:
  completions: 4
  parallelism: 2

  template:
    spec:
      containers:
        - name: worker
          image: busybox
          command:
            - sh
            - -c
            - echo "Processing..." && sleep 10

      restartPolicy: Never
EOF
```
```bash
completions: 4
parallelism: 2
```

Kubernetes can run:
```
Time →


Pod-1 ──────────> Completed
Pod-2 ──────────> Completed
                     ↓
                  Pod-3 ────────> Completed
                  Pod-4 ────────> Completed
```

Maximum:
```
2 Pods running simultaneously
```

Total successful completions:
```
4
```

Therefore:
```
parallelism = 2
completions = 4
```

means:
```
"I need 4 successful executions, but run at most 2 at the same time."
```