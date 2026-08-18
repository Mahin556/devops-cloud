For a Kubernetes **Job**, these are the important defaults to remember. Some fields are not actually defaulted by the API because they are optional, so it's useful to distinguish the effective/default behavior from fields you must specify.

### Kubernetes Job defaults

| Field                     |                            Default | Meaning                                                    |
| ------------------------- | ---------------------------------: | ---------------------------------------------------------- |
| `completions`             |                                `1` | Job needs 1 successful completion                          |
| `parallelism`             |                                `1` | At most 1 Pod runs at a time                               |
| `backoffLimit`            |                                `6` | Up to 6 counted Pod failures before Job is failed          |
| `activeDeadlineSeconds`   |                            Not set | No overall time limit                                      |
| `ttlSecondsAfterFinished` |                            Not set | Job is **not automatically deleted** after completion      |
| `suspend`                 |                            `false` | Job starts running                                         |
| `completionMode`          |                       `NonIndexed` | Pods are not assigned completion indexes                   |
| `podFailurePolicy`        |                            Not set | Default failure handling                                   |
| `successPolicy`           |                            Not set | Job completes based on normal completion rules             |
| `manualSelector`          |                            `false` | Kubernetes generates/manages the selector                  |
| `restartPolicy`           | **Must be `Never` or `OnFailure`** | Jobs don't use the normal Deployment-style `Always` policy |

### The 4 you should memorize

```yaml
spec:
  completions: 1       # default
  parallelism: 1       # default
  backoffLimit: 6      # default
  restartPolicy: Never # commonly used; must be Never or OnFailure
```

So if you write only:

```yaml
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
          command: ["sh", "-c", "echo Hello"]

      restartPolicy: Never
```

the effective behavior is roughly:

```text
completions = 1
parallelism = 1
backoffLimit = 6
```

Therefore:

```text
             Job
              |
         creates Pod
              |
          Pod succeeds
              |
         1/1 completion
              |
         Job Complete
```

### Important interview point

Don't say:

> "`restartPolicy` defaults to `Never` for Jobs."

That's misleading.

For a Job Pod template, Kubernetes requires `restartPolicy` to be either **`Never` or `OnFailure`**; you should explicitly specify one. The default Pod `restartPolicy` of `Always` is **not valid for a Job**.

Also, `ttlSecondsAfterFinished` has **no default cleanup time**. If you don't specify it, Kubernetes doesn't automatically delete the finished Job merely because it completed.
