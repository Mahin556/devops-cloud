```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job

spec:
  completions: 2

  template:
    spec:
      containers:
        - name: hello
          image: busybox
          command:
            - sh
            - -c
            - echo "Hello from Job"

      restartPolicy: Never
EOF
```

The Job needs:
```bash
Successful completions = 2
```

Kubernetes might create:
```bash
Pod 1 → Completed
Pod 2 → Completed
```

Then:
```bash
Job → Complete
```

Check:
```bash
kubectl get job
```

You should eventually see:
```bash
NAME         COMPLETIONS
hello-job    2/2
```

Important

completions means:
```
How many successful Pod executions are required for the Job to be considered complete.
```

It does not mean:
```
"Create exactly two Pods."
```

Retries can cause additional Pods.