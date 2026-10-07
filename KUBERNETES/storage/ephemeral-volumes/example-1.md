The Pod uses a **generic ephemeral volume** — a volume whose lifecycle is tied to the Pod. Under the hood, the ephemeral volume controller creates a PVC (from the `volumeClaimTemplate`) and binds it to the Pod. When the Pod is deleted, the PVC and the underlying PV are garbage-collected.

## 1. Namespace (if it doesn't already exist)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: analytics
```

## 2. Pod Manifest

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: analytics-worker
  namespace: analytics
spec:
  containers:
    - name: worker
      image: cgr.dev/chainguard/busybox:latest
      command:
        - /bin/sh
        - -c
        - "mkdir -p /data && echo '# Analytics Report' > /data/index.md && sleep 3600"
      volumeMounts:
        - name: ephemeral-storage
          mountPath: /data

  volumes:
    - name: ephemeral-storage
      ephemeral:
        volumeClaimTemplate:
          spec:
            accessModes:
              - ReadWriteOnce
            storageClassName: local-path
            resources:
              requests:
                storage: 1Gi
```

### Key points

| Part | Explanation |
|------|-------------|
| `volumes[].ephemeral.volumeClaimTemplate` | The generic ephemeral volume shape. The controller creates a PVC named `analytics-worker-ephemeral-storage` (or similar) in the same namespace. |
| `volumeClaimTemplate.spec` | Same shape as a normal `PersistentVolumeClaim` spec — `accessModes`, `storageClassName`, `resources.requests.storage`. No `metadata` or `kind` here; they are generated. |
| `storageClassName: local-path` | Uses the `local-path` provisioner. This must exist in your cluster (common in k3s, Rancher, or after installing `local-path-provisioner`). |
| `volumeMounts[].mountPath: /data` | The container sees the ephemeral volume at `/data`, which is where the command writes `index.md`. |
| `accessModes: [ReadWriteOnce]` | Standard for a single-node local volume. |

## 3. Apply

```bash
kubectl apply -f namespace.yaml
kubectl apply -f analytics-worker.yaml
```

Or as a single command if the namespace already exists:

```bash
kubectl apply -f analytics-worker.yaml
```

## 4. Verify the Pod is running

```bash
kubectl get pod analytics-worker -n analytics -w
```

Wait for `STATUS: Running`.

Check the generated PVC:

```bash
kubectl get pvc -n analytics
# NAME                          STATUS   VOLUME      CAPACITY   ACCESS MODES   STORAGECLASS
# analytics-worker-ephemeral-storage   Bound    pvc-...     1Gi        RWO            local-path
```

## 5. Verify the file was written

```bash
kubectl exec analytics-worker -n analytics -c worker -- cat /data/index.md
```

Expected output:

```
# Analytics Report
```

You can also inspect the mount inside the container:

```bash
kubectl exec analytics-worker -n analytics -c worker -- ls -l /data
# total 4
# -rw-r--r--    1 root     root            18 ... index.md
```

## 6. Cleanup

Because the volume is ephemeral, deleting the Pod also deletes the PVC and the PV:

```bash
kubectl delete pod analytics-worker -n analytics
```

Confirm the PVC is gone:

```bash
kubectl get pvc -n analytics
# No resources found
```

## StorageClass
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    defaultVolumeType: local
    objectset.rio.cattle.io/applied: H4sIAAAAAAAA/4yRz47UMAyHXwX53JYpnamqSBxg0V4QEhJoObuJOzVN4ypxi0areXeUMqDhwJ9j8ov9xZ+fARd+ophYAhhIKhHPVE1dqlhebjUUMHFwYODTj+jBY0pQwEyKDhXBPAOGIIrKElI+Ohpw9fokfp3p82UhMODFoocCpP9KVhNpFVkqi6qeMokz4i+5fAsUy/M2gYGpSXfJVhcv3nNwr984J+GfLQLOv/5T3sb9r6K0oM2V09pTmS5JaYbipzCbrVQ5ioGUdnmcypuJco/BgMaV4FqAx5787upP3BHTCAbqrhmak21Pw9Db5tAe20MzHJuhPnUH19m2w1cOe3fMTX+bbEEd8+USZeO8XIpgIGKwI8UMuHtWQMwD8PxRPNsLGHhHnjRr2fYdvuXgOJw/iMuAL8j6KPGRY9IHCWmdKcL1ewAAAP//KQ1Ko0kCAAA
    objectset.rio.cattle.io/id: ""
    objectset.rio.cattle.io/owner-gvk: k3s.cattle.io/v1, Kind=Addon
    objectset.rio.cattle.io/owner-name: local-storage
    objectset.rio.cattle.io/owner-namespace: kube-system
    storageclass.kubernetes.io/is-default-class: "true"
  creationTimestamp: "2026-09-13T05:38:00Z"
  labels:
    objectset.rio.cattle.io/hash: 183f35c65ffbc3064603f43f1580d8c68a2dabd4
  name: local-path
  resourceVersion: "315"
  uid: 234768a9-9dde-4bf9-8785-976231b1fbc1
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

## Notes & troubleshooting

- **StorageClass `local-path` missing?** The Pod will stay `Pending` with an event like `pod has unbound immediate PersistentVolumeClaims`. Install a provisioner (e.g., Rancher `local-path-provisioner`) or change `storageClassName` to one that exists in your cluster.
- **Chainguard `busybox` image:** It is a minimal, non-root-oriented image. If the container fails with a permission error writing to `/data`, check the Pod's `securityContext`. The default `local-path` provisioner usually allows root, and the Chainguard image runs as a non-root user by default in some tags. If needed, add:
  ```yaml
  securityContext:
    runAsUser: 0
  ```
  under the container, or use an image that runs as root by default.
- **Generic ephemeral volumes** require the `GenericEphemeralVolume` feature gate, which is **enabled by default** in Kubernetes 1.23+. No extra configuration is needed on modern clusters.
- **The volume is Pod-scoped.** It is not shared with other Pods, and it is destroyed when the Pod is deleted — unlike a manually created PVC, which persists.