```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job

spec:
  template:
    spec:
      containers:
        - name: hello
          image: busybox
          command: ["sh", "-c", "echo Hello from Job"]

      restartPolicy: Never
EOF
```
```bash
kubectl get jobs
kubectl get pods
```
```bash
kubectl logs job/hello-job
```
```bash
Job created
   ↓
Job Controller creates Pod
   ↓
Pod starts
   ↓
Container executes command
   ↓
echo Hello from Job
   ↓
Container exits with code 0
   ↓
Pod = Completed
   ↓
Job = Complete
```