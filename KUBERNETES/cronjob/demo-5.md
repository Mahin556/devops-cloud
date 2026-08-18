# Daily Database Backup

A more realistic example.

```yaml
apiVersion: batch/v1
kind: CronJob

metadata:
  name: database-backup

spec:
  schedule: "0 2 * * *"

  timeZone: "Asia/Kolkata"

  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3

  concurrencyPolicy: Forbid

  jobTemplate:
    spec:
      backoffLimit: 3

      template:
        spec:
          containers:
            - name: backup
              image: mysql:8.0

              env:
                - name: MYSQL_HOST
                  value: "mysql"

                - name: MYSQL_USER
                  value: "backup"

                - name: MYSQL_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: mysql-secret
                      key: password

              command:
                - sh
                - -c
                - |
                  echo "Starting database backup..."

                  mysqldump \
                    -h "$MYSQL_HOST" \
                    -u "$MYSQL_USER" \
                    -p"$MYSQL_PASSWORD" \
                    database > /backup/database.sql

                  echo "Backup completed."

          restartPolicy: Never
```

### Why `Forbid`?

```yaml
concurrencyPolicy: Forbid
```

Suppose the backup normally takes 30 minutes.

But one day it takes 70 minutes.

The next scheduled backup occurs while the previous one is still running.

With:

```text
Forbid
```

Kubernetes won't start another backup concurrently.

```text
02:00
 │
 └── Backup-1 ────────────────────────>
                                      │
03:00 ────────────────────────────────X
                                      │
                                new backup skipped
```

This is useful for database backups because running two backups simultaneously may create unnecessary load.