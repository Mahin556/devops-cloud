Example 8 — completions + parallelism + backoffLimit

This is a very good interview example.

```bash
kubectl apply -f -<<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: processing-job
spec:
  completions: 6
  parallelism: 2
  backoffLimit: 3
  template:
    spec:
      containers:
        - name: processor
          image: busybox
          command:
            - sh
            - -c
            - echo "Processing item"; sleep 5
      restartPolicy: Never
EOF
```

Meaning:

completions = 6
        ↓
Need 6 successful executions


parallelism = 2
        ↓
Maximum 2 Pods at once


backoffLimit = 3
        ↓
Job can tolerate configured failures/retries

Possible execution:

             Job
              |
       +------+------+
       |             |
    Pod-1          Pod-2
   Success         Success
       |             |
       +------+------+
              |
       +------+------+
       |             |
    Pod-3          Pod-4
   Success         Failed
                     |
                  retry
                     |
                  Pod-5
                  Success
       |             |
       +------+------+
              |
       +------+------+
       |             |
    Pod-6          Pod-7
   Success         Success
              |
        6 successful
        completions
              |
          Job Complete

There can be more than 6 Pods because failed attempts may require replacement Pods.