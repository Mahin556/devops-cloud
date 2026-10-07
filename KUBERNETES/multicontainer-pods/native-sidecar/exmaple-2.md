# Without the `startupProbe`

The `startupProbe` is the **handoff signal** for a native sidecar. Remove it, and the kubelet has nothing to gate on — so it falls back to the only other thing it can observe about an init container that never exits: **that it started**.

## What changes in the manifest

Only the probe block is deleted:

```yaml
  initContainers:
    - name: logger
      image: busybox
      restartPolicy: Always
      command: ["sh", "-c", "sleep 30; date >> /data/log.txt; sleep infinity"]
      volumeMounts:
        - name: shared-vol
          mountPath: /data
      # startupProbe:  <-- removed
      #   exec:
      #     command: ["test", "-s", "/data/log.txt"]
      #   periodSeconds: 2
      #   failureThreshold: 30
```

Everything else — `restartPolicy: Always` on the container, `app` reading the file once — stays the same.

## What the kubelet does instead

For a plain init container (no `restartPolicy: Always`), the kubelet waits for the process to **exit 0**.

For a **sidecar** (`restartPolicy: Always`), the process never exits by design, so "wait for exit" is meaningless. The kubelet substitutes a different condition:

| `startupProbe` present? | Kubelet waits for… | Then starts `app` |
|---|---|---|
| Yes | probe to **succeed** | after the probe passes → file is guaranteed written |
| No | container to be **started** (state `Running`) | almost immediately → file may not exist yet |

So without the probe, the gate opens as soon as the `logger` process is alive — which is **before** `sleep 30` even finishes. `app` starts while `logger` is still sleeping.

## What you'd observe

```bash
kubectl get pod native-sidecar-pod -w
```

```
native-sidecar-pod   0/1   Init:0/1          ...   # logger starting
native-sidecar-pod   0/1   PodInitializing   ...   # logger Running -> gate opens
native-sidecar-pod   1/1   Running           ...   # app up, ~30s BEFORE logger writes
```

No 30-second stall in `Init:0/1`. The Pod reaches `Running` in a second or two.

And the app's one-shot read loses the race:

```bash
kubectl logs native-sidecar-pod -c app
# cat: can't open '/data/log.txt': No such file or directory
```

(`cat` fails, prints the error, then `sleep infinity` keeps the container running — which is why the Pod still shows `Running` and looks healthy.)

If you exec in **later**, the file is there:

```bash
kubectl exec native-sidecar-pod -c app -- cat /data/log.txt
# Fri Sep 12 ... 2026     <- written by logger after app already gave up
```

That's the proof: the ordering guarantee held (logger started first), but the **readiness** guarantee did not — `app` ran its `cat` before `logger` produced the data.

## Why the probe is the whole point

- `restartPolicy: Always` on an `initContainers` entry buys you **ordering + lifespan**: the sidecar is started before the main containers and keeps running alongside them. It does **not** buy you *"it has finished its startup work."*
- The `startupProbe` is how you express that second guarantee. `test -s /data/log.txt` (non-empty) is the sidecar announcing "I'm ready for the app to proceed."
- With it, the kubelet holds `app` in `PodInitializing` until the probe passes → the single `cat` always finds the line.
- Without it, you're back to a race — exactly the race a native sidecar is supposed to eliminate. You've essentially recreated the plain-sidecar problem (both start together, no readiness handshake), just with the sidecar forced to start first.

So: the probe isn't optional decoration on a sidecar — it's the mechanism that turns "starts before" into "is ready before."