`restartPolicy: OnFailure`

Now change:
```
restartPolicy: OnFailure
```

Example:
```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: retry-inside-pod
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
            - |
              echo "Running..."
              exit 1
      restartPolicy: OnFailure
EOF
```

Now the behavior is different.

The container exits with:
```
exit 1
```

The kubelet sees:
```
restartPolicy = OnFailure
```

so it restarts the container inside the same Pod.

Conceptually:
```
Pod-1
 │
 └── Container
       │
       ├── Run → exit 1
       │
       ├── Restart
       │
       ├── Run → exit 1
       │
       ├── Restart
       │
       └── ...
```

Notice:

The Pod itself is not recreated for each container restart.

You can observe this with:
```
kubectl get pod
```

and:
```
kubectl describe pod <pod-name>
```

You'll see the container's restart count increasing.