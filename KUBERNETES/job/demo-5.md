### Failed Job with restartPolicy: Never

This is the example that usually causes confusion.
```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: failed-job
spec:
  backoffLimit: 3
  template:
    spec:
      containers:
        - name: worker
          image: busybox
          command:
            - sh
            - -c
            - echo "Something went wrong"; exit 1
      restartPolicy: Never
EOF
```

The container exits:
```
exit 1
```

Therefore:
```
Container
   ↓
Failed
   ↓
Pod
   ↓
Failed
```

Because:
```
restartPolicy: Never
```

the kubelet does not restart the container.

Instead:
```
Job Controller
      ↓
sees failed Pod
      ↓
creates another Pod
```

For example:
```
job
 ↓
Pod-1 → Failed
 ↓
Pod-2 → Failed
 ↓
Pod-3 → Failed
 ↓
Pod-4 → Failed
 ↓
Job → Failed
```

This is the key distinction.