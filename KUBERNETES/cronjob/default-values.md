For Kubernetes **CronJob**, these are the important default values to remember. A CronJob creates **Jobs** according to its schedule.

### CronJob default values

| Field                        |      Default | Meaning                                           |
| ---------------------------- | -----------: | ------------------------------------------------- |
| `concurrencyPolicy`          |      `Allow` | Multiple Jobs can run concurrently                |
| `suspend`                    |      `false` | Schedule is active                                |
| `successfulJobsHistoryLimit` |          `3` | Keep last 3 successful Jobs                       |
| `failedJobsHistoryLimit`     |          `1` | Keep last 1 failed Job                            |
| `startingDeadlineSeconds`    |      Not set | No deadline for starting a missed Job             |
| `jobTemplate`                |     Required | Defines the Job to create                         |
| `schedule`                   | **Required** | Cron schedule                                     |
| `timeZone`                   |      Not set | Uses controller's local time zone                 |
| `startingDeadlineSeconds`    |      Not set | Missed executions aren't limited by this field    |
| `ttlSecondsAfterFinished`    |      Not set | Finished Jobs aren't automatically deleted by TTL |

### The important ones to memorize

```yaml
spec:
  schedule: "*/5 * * * *"       # REQUIRED

  concurrencyPolicy: Allow      # default

  suspend: false                # default

  successfulJobsHistoryLimit: 3 # default

  failedJobsHistoryLimit: 1     # default
```

---

## Example: Minimal CronJob

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: backup-cronjob

spec:
  schedule: "*/5 * * * *"

  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: busybox
              command:
                - sh
                - -c
                - echo "Running backup..."

          restartPolicy: Never
```

Because we didn't specify the optional fields, Kubernetes effectively uses:

```text
concurrencyPolicy          → Allow
suspend                    → false
successfulJobsHistoryLimit → 3
failedJobsHistoryLimit     → 1
startingDeadlineSeconds    → not set
```

---

# 1. `concurrencyPolicy: Allow`

Default:

```yaml
concurrencyPolicy: Allow
```

This means a new Job **can start even if the previous Job is still running**.

For example:

```text
Schedule: every 1 minute

Job-1 ──────────────── running
       │
       └── 1 minute ──> Job-2 starts
                        │
                        └── running
```

You can have:

```text
Job-1 → Running
Job-2 → Running
Job-3 → Running
```

This is the default.

---

# 2. `concurrencyPolicy: Forbid`

If you use:

```yaml
concurrencyPolicy: Forbid
```

a new Job will **not start while the previous Job is still running**.

```text
Job-1 ─────────────── Running ───────────> Complete
              │
              │ scheduled time
              ↓
          Job-2 skipped
```

Useful for:

* Database backups
* Reports
* Data processing
* Tasks that must not overlap

---

# 3. `concurrencyPolicy: Replace`

```yaml
concurrencyPolicy: Replace
```

If the previous Job is still running when the next schedule occurs, Kubernetes replaces the currently running Job with the new one.

```text
Job-1 ───────────── Running ──────────────X
                         │
                    schedule occurs
                         ↓
                       Job-2
                         │
                         └──── Running
```

So:

```text
Allow   → Run both
Forbid  → Skip new run
Replace → Replace old run
```

---

# 4. `successfulJobsHistoryLimit`

Default:

```yaml
successfulJobsHistoryLimit: 3
```

Suppose your CronJob runs every hour:

```text
Job-1 → Complete
Job-2 → Complete
Job-3 → Complete
Job-4 → Complete
```

Kubernetes keeps approximately the latest:

```text
Job-2
Job-3
Job-4
```

and removes older successful Jobs.

This is useful for preventing unlimited accumulation of completed Jobs.

---

# 5. `failedJobsHistoryLimit`

Default:

```yaml
failedJobsHistoryLimit: 1
```

Suppose:

```text
Job-1 → Failed
Job-2 → Failed
Job-3 → Failed
```

Kubernetes retains the most recent failed Job according to this history limit.

---

# 6. `suspend`

Default:

```yaml
suspend: false
```

Meaning:

```text
CronJob schedule is active
```

If you set:

```yaml
suspend: true
```

Kubernetes stops creating new Jobs from the schedule.

Important:

> `suspend: true` does not automatically delete Jobs that are already running.

---

# 7. `startingDeadlineSeconds`

Default:

```text
Not set
```

This controls how long Kubernetes can wait before deciding that a missed schedule is too old to start.

Example:

```yaml
startingDeadlineSeconds: 100
```

means Kubernetes can start a missed execution if it is within the specified deadline.

Without it:

```text
startingDeadlineSeconds
        ↓
       unset
```

there is no deadline configured through this field.

---

# 8. `timeZone`

Modern Kubernetes CronJobs support:

```yaml
timeZone: "Asia/Kolkata"
```

If you don't specify it:

```text
timeZone → not set
```

The schedule is interpreted using the **kube-controller-manager's local time zone**.

For production CronJobs, explicitly specifying the timezone can make the schedule much clearer:

```yaml
spec:
  schedule: "0 2 * * *"
  timeZone: "Asia/Kolkata"
```

This means:

> Run every day at 2:00 AM India time.

---

# 9. `ttlSecondsAfterFinished`

This is an important distinction.

CronJob has:

```yaml
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1
```

but the **Job itself** can also have:

```yaml
ttlSecondsAfterFinished: 300
```

For example:

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: backup

spec:
  schedule: "0 2 * * *"

  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1

  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 300

      template:
        spec:
          containers:
            - name: backup
              image: busybox
              command:
                - sh
                - -c
                - echo "Backup completed"

          restartPolicy: Never
```

Here:

```text
CronJob
   |
   ├── Job-1
   ├── Job-2
   ├── Job-3
   └── Job-4
```

The CronJob history limits control how many completed Job objects are retained, while `ttlSecondsAfterFinished` provides TTL-based cleanup for finished Jobs.

---

# 10. CronJob defaults vs Job defaults

This is a very useful interview comparison:

| Setting                      |                          Job |                             CronJob |
| ---------------------------- | ---------------------------: | ----------------------------------: |
| `completions`                |                          `1` |            Comes from `jobTemplate` |
| `parallelism`                |                          `1` |            Comes from `jobTemplate` |
| `backoffLimit`               |                          `6` |            Comes from `jobTemplate` |
| `restartPolicy`              | `Never`/`OnFailure` required | `Never`/`OnFailure` in Job template |
| `concurrencyPolicy`          |                          N/A |                             `Allow` |
| `suspend`                    |                          N/A |                             `false` |
| `successfulJobsHistoryLimit` |                          N/A |                                 `3` |
| `failedJobsHistoryLimit`     |                          N/A |                                 `1` |
| `startingDeadlineSeconds`    |                          N/A |                             Not set |
| `schedule`                   |                          N/A |                        **Required** |

### Mental model

```text
CronJob
   │
   │ schedule
   ↓
Creates Job
   │
   │ jobTemplate
   ↓
Creates Pod
   │
   ↓
Container
```

So remember:

```text
CronJob defaults
    ↓
Scheduling behavior

Job defaults
    ↓
Execution behavior

Pod restartPolicy
    ↓
Container behavior
```

The **5 CronJob values most worth memorizing for interviews** are:

```text
concurrencyPolicy          = Allow
suspend                    = false
successfulJobsHistoryLimit = 3
failedJobsHistoryLimit     = 1
startingDeadlineSeconds    = unset
```
