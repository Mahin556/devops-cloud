## 🔹 Two Ways to Use Downward API

1. **Environment Variables**

   * Inject Pod/Container metadata into env vars (what we just did).
   * Good for small data (like Pod name, namespace, IP, labels, annotations).

2. **DownwardAPI Volume Files**

   * Expose the same information via files mounted into the container.
   * Better for large/unstructured data (like annotations or labels).

### Behavior
- Env vars → evaluated once at container startup (static).
- Volumes → files updated dynamically if values change (e.g., resizing CPU/memory in K8s v1.33+).

---

## 🔹 Exposing Pod/Container Info via **Volume Files**

Here’s an example of using a `downwardAPI` volume:

```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: downward-api-volume-demo
  labels:
    app: myapp
    tier: backend
  annotations:
    description: "This is a demo pod"
spec:
  containers:
    - name: test-container
      image: busybox
      command: [ "sh", "-c"]
      args:
      - while true; do
          echo "== Files ==";
          cat /etc/podinfo/labels;
          cat /etc/podinfo/annotations;
          sleep 10;
        done;
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations
EOF
```

**What happens:**

* Kubernetes writes **Pod labels** → `/etc/podinfo/labels`
* Kubernetes writes **Pod annotations** → `/etc/podinfo/annotations`
* Your app can read them like files.

---


## 🔹 Things to Remember

* **Read-only** → Containers cannot modify Pod fields via Downward API.
* **Static Snapshot** → Values are injected at Pod startup (some updates like labels/annotations can reflect dynamically in volumes, but env vars won’t change).
* **Security** → Avoid exposing sensitive info like secrets here. Use `Secrets` instead.

---

✅ So far you’ve learned:

* Downward API with **env vars** (Pod & container info).
* Downward API with **volumes** (labels & annotations).
* Real-world **use cases** like logging, monitoring, config, resource awareness.