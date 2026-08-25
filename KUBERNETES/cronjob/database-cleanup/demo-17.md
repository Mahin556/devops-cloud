## Run a database cleanup job every night at a specific time, but ONLY in the staging environment (not dev or production).

**Challenge:** Kubernetes doesn't inherently isolate jobs to specific environments. You need to ensure the CronJob only runs in the staging namespace.

**Solution:**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: db-cleanup
  namespace: staging  # Deploy ONLY in staging namespace
spec:
  schedule: "0 2 * * *"  # Daily at 2:00 AM UTC (7:30 AM IST)
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: db-cleanup-tool:latest
            args:
            - "cleanup"
            - "staging"
          restartPolicy: OnFailure
```

Apply it specifically to staging:
```bash
kubectl apply -f cronjob.yaml -n staging
```

**Key Points:**
- **CronJob resource** handles scheduled tasks
- Deploy the CronJob manifest ONLY in the staging namespace
- `schedule` uses Cron format: `"0 2 * * *"` = daily at 2 AM UTC
- `restartPolicy: OnFailure` means the pod restarts only if it fails, not on success
- The job is completely isolated from dev and production environments
- The namespace ensures no cross-environment impact