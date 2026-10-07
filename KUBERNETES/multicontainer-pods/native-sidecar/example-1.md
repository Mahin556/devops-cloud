The `logger` entry lives under `initContainers` but declares its **own** `restartPolicy: Always` on the container. That single field flips its semantics: instead of "run to completion, then move on," the kubelet treats it as a **native sidecar** — it starts it in order, but gates the main containers on the container's `startupProbe` passing (not on the process exiting). The probe polls `test -s /data/log.txt`, which only succeeds after the `sleep 30` finishes and the date is appended.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: native-sidecar-pod
  labels:
    run: native-sidecar-pod
spec:
  # Pod-level restart policy — unrelated to the sidecar gating below(only for main application containers).
  restartPolicy: Always

  volumes:
    - name: shared-vol
      emptyDir: {}

  initContainers:
    - name: logger
      image: busybox
      # restartPolicy on the CONTAINER is what makes this a native sidecar.
      # It must be "Always" for sidecar semantics; any other value = plain init container.
      restartPolicy: Always
      command: ["sh", "-c", "sleep 30; date >> /data/log.txt; sleep infinity"]
      volumeMounts:
        - name: shared-vol
          mountPath: /data
      startupProbe:
        exec:
          command: ["test", "-s", "/data/log.txt"]
        periodSeconds: 2
        failureThreshold: 30

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
kubectl apply -f native-sidecar-pod.yaml
```

## Watch the gating live

```bash
kubectl get pod native-sidecar-pod -w
```

What you'll see:

```
native-sidecar-pod   0/1   Init:0/1   ...   # logger started, probe failing (no file yet)
native-sidecar-pod   0/1   Init:0/1   ...   # ~30s of this while sleep runs
native-sidecar-pod   0/1   PodInitializing  # probe passed -> app starting
native-sidecar-pod   1/1   Running    ...   # app up
```

The Pod sits in `Init:0/1` for about 30 seconds — that's the `sleep 30`, with the `startupProbe` failing every 2 seconds (`test -s` on a missing/empty file). Once the date is written, the probe succeeds, the kubelet stops waiting for exit and starts `app`.

## Prove the app saw the data

```bash
kubectl logs native-sidecar-pod -c app
# Fri Sep 12 ... 2026   <- a real timestamp; the file was non-empty at app start
```

The app container reads `/data/log.txt` exactly once, immediately, and it is **guaranteed non-empty** because the probe gated its start on that. Contrast with a plain sidecar (no `restartPolicy: Always` + probe): the app could race the logger and `cat` an empty file.

You can also confirm both containers are alive simultaneously after startup:

```bash
kubectl get pod native-sidecar-pod -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}'
# logger app
kubectl logs native-sidecar-pod -c logger
# (no output yet — logs its date to the file, not stdout)
```

## Why this is a native sidecar, not a plain init container

| | Plain init container | Native sidecar (`initContainers[].restartPolicy: Always`) |
|---|---|---|
| When does the next stage start? | After it **exits** (code 0) | After its `startupProbe` **passes** (it keeps running) |
| Does it stay running alongside the app? | No — must exit first | Yes — lives for the Pod's lifetime |
| Lifespan | Dies before main containers start | Same as main containers; restarts with Pod policy |
| Can it hold a proxy / log shipper? | No | Yes |

- The **ordering guarantee** of an init container is preserved: `logger` is started before `app`.
- The **lifespan** is that of a sidecar: `sleep infinity` keeps it alive, and it's still running when `app` is up.
- The `startupProbe` is the handoff signal. Without it, the kubelet would need the container to exit to proceed — which would defeat the purpose. With it, readiness of the ongoing capability is the gate.
- `periodSeconds: 2` × `failureThreshold: 30` = up to 60 seconds allowed for startup, comfortably covering the 30-second `sleep`.

### Cleanup

```bash
kubectl delete pod native-sidecar-pod
```