A single Pod. Init containers run **sequentially** and to completion (exit 0) before the next one starts — that guarantee is what makes the append order deterministic. The `emptyDir` volume is shared across init containers and the main container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-pod
  labels:
    run: init-pod
spec:
  # restartPolicy controls what happens if an *app* container exits.
  # It has no effect on init-container ordering — those always run to completion.
  restartPolicy: Always

  volumes:
    - name: shared-vol
      emptyDir: {}

  initContainers:
    - name: init1
      image: busybox
      command: ["sh", "-c", "echo init1 >> /data/log.txt"]
      volumeMounts:
        - name: shared-vol
          mountPath: /data

    - name: init2
      image: busybox
      command: ["sh", "-c", "echo init2 >> /data/log.txt"]
      volumeMounts:
        - name: shared-vol
          mountPath: /data

  containers:
    - name: app
      image: busybox
      command: ["sh", "-c", "cat /data/log.txt; sleep infinity"]
      volumeMounts:
        - name: shared-vol
          mountPath: /data
```

## Apply

```bash
kubectl apply -f init-pod.yaml
```

## Watch the transitions

```bash
kubectl get pod init-pod -w
```

You'll see the phases progress in order:

```
init-pod   0/1   Init:0/2    ...   # init1 running
init-pod   0/1   Init:1/2    ...   # init1 done, init2 running
init-pod   0/1   PodInitializing  # both inits done, app starting
init-pod   1/1   Running     ...   # app up
```

## Verify the order held

The app container reads the file **once**, after both init containers have exited. Because init containers are strictly serialized, that read always finds both lines, in order:

```bash
kubectl logs init-pod -c app
# init1
# init2
```

You can also read the file directly from the running app container:

```bash
kubectl exec init-pod -c app -- cat /data/log.txt
# init1
# init2
```

## Why the order is guaranteed

- Kubernetes runs `initContainers` **one at a time, in list order**. `init2` does not start until `init1` has exited successfully (exit code 0).
- The main `app` container does not start until **all** init containers have completed. So `cat` always runs after both appends.
- `shared-vol` is an `emptyDir` mounted into every container in the Pod, so it survives across the init containers and into the app container for the lifetime of the Pod.
- `.spec.restartPolicy` (here `Always`, the default) decides what happens when the **app** container exits — restart it. It does not change init-container sequencing. If an init container fails with a non-zero exit and the restart policy permits, the kubelet retries it; on a non-restartable Pod it would fail the Pod. That's the "exit code branches through restartPolicy" bit — but the append-order proof is unaffected because a failed init never lets the next stage begin.

### Cleanup

```bash
kubectl delete pod init-pod
```