## 🧩 **What’s happening**

1. You tried to do:

```bash
kubectl set env pod immutable-demo-pod --from=configmap/demo-config-v2
```

2. The Pod `immutable-demo-pod` **already exists** and is **not managed by a Deployment**.

3. Kubernetes **does not allow changing environment variables on an existing Pod**.
   Only a few fields can be updated on a live Pod, such as:

* `spec.containers[*].image`
* `spec.initContainers[*].image`
* `spec.activeDeadlineSeconds`
* `spec.tolerations`
* `spec.terminationGracePeriodSeconds`

Trying to change environment variables (or volumes) directly on a Pod triggers:

```
Pod updates may not change fields other than ...
```

That’s exactly what you see.

---

## 🧠 **Key Rule**

> **Pods are immutable objects in Kubernetes.**
> You cannot change env vars, ConfigMap volumes, or command args on a live Pod.
> To update them, you must **replace the Pod** or manage it via a **Deployment/StatefulSet**.

---

## ⚙️ **How to fix it**

### ✅ **Option 1 — Delete & recreate the Pod**

```bash
kubectl delete pod immutable-demo-pod
kubectl apply -f immutable-demo-pod.yaml
```

This creates a new Pod with the updated environment variable from the ConfigMap.

---

### ✅ **Option 2 — Use a Deployment**

If you create a Deployment, you can update ConfigMaps and **trigger a rolling update** safely:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-demo-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sh", "-c", "echo FOO=$FOO && sleep 3600"]
          env:
            - name: FOO
              valueFrom:
                configMapKeyRef:
                  name: demo-config-v2
                  key: foo
```

Apply the Deployment:

```bash
kubectl apply -f demo-deployment.yaml
```

Now, **updating the Deployment** environment triggers new Pods with the new ConfigMap value:

```bash
kubectl set env deployment/immutable-demo-deploy --from=configmap/demo-config-v2
```

✅ Works without deleting the Deployment manually.

---

### 🔑 **Summary**

| Action                        | Pod                       | Deployment                         |
| ----------------------------- | ------------------------- | ---------------------------------- |
| Change env var from ConfigMap | ❌ Not allowed on live Pod | ✅ Allowed (creates new ReplicaSet) |
| Change volume mount           | ❌ Not allowed on live Pod | ✅ Allowed with rolling update      |
| Immutable ConfigMap           | ❌ Cannot modify anyway    | ✅ Works with new Pods              |

### References:
- https://spacelift.io/blog/kubernetes-configmap