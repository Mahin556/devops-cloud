Example 9 — ttlSecondsAfterFinished

Your example has:

ttlSecondsAfterFinished: 60

This means:

After the Job reaches a terminal state (Complete or Failed), Kubernetes can automatically delete the Job after 60 seconds.

Example:

Job running
    ↓
Job Complete
    ↓
wait 60 seconds
    ↓
Job deleted

Example:

apiVersion: batch/v1
kind: Job
metadata:
  name: cleanup-job
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      containers:
        - name: worker
          image: busybox
          command: ["sh", "-c", "echo Done"]
      restartPolicy: Never

Check:

kubectl get jobs

Immediately after completion:

cleanup-job

After approximately 60 seconds, the Job will be garbage-collected.