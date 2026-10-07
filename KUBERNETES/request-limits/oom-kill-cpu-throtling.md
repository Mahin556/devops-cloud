# 🔥 OOM Killer & CPU Throttling in Kubernetes

## 1. Where This Comes From

Kubernetes relies on the **Linux kernel cgroups** to enforce pod resource limits.

* **Memory limits** → enforced strictly → if exceeded → **OOMKill**.
* **CPU limits** → enforced softly → if exceeded → **CPU throttling**.

---

## 2. Memory Requests & Limits → OOM Killer

### Behavior

* **Request (memory)** → used only for scheduling. Node must have that much free RAM.
* **Limit (memory)** → hard maximum.

  * If a container tries to use more → **OOM (Out Of Memory) Killer** terminates it.

### What happens

1. Pod exceeds memory limit.
2. Kernel cgroup detects overuse.
3. Container is killed → status shows `OOMKilled`.
4. Kubelet may restart it (depending on `restartPolicy`).

### Check if OOMKilled

```bash
kubectl describe pod <pod-name>
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'
```

### Example

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"
```

🔹 Pod is scheduled if node has ≥ 256Mi RAM.
🔹 If it tries to use >512Mi → **OOMKilled**.

---

## 3. CPU Requests & Limits → Throttling

### Behavior

* **Request (CPU)** → Scheduler guarantees CPU cycles.
* **Limit (CPU)** → Upper bound.

  * Exceeding limit does **not kill** the pod.
  * Instead, Linux cgroups **throttle CPU** usage.

### What happens

1. Pod requests `500m` (0.5 core), limit is `1` (1 core).
2. Pod can burst up to 1 core.
3. If it tries to use >1 core → kernel throttles → pod slows down, no kill.

### Example

```yaml
resources:
  requests:
    cpu: "500m"
  limits:
    cpu: "1"
```

🔹 Pod is guaranteed half a CPU.
🔹 Can burst up to 1 CPU.
🔹 If app tries to use 2 CPUs → throttled back to 1.

---

## 4. Combined Example – OOMKill + CPU Throttling

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
spec:
  containers:
  - name: stress
    image: polinux/stress
    args: ["--cpu", "2", "--vm", "1", "--vm-bytes", "700M", "--vm-hang", "1"]
    resources:
      requests:
        memory: "256Mi"
        cpu: "500m"
      limits:
        memory: "512Mi"
        cpu: "1"
```

🔹 What happens:

* Pod scheduled only if node has ≥0.5 CPU and ≥256Mi RAM.
* If it uses >1 CPU → throttled.
* If it uses >512Mi → killed by OOM killer.

---

## 5. QoS Class Interaction

* **Guaranteed (requests == limits)** → least likely to be OOMKilled if node runs out of memory.
* **Burstable** → more likely to be killed than Guaranteed.
* **BestEffort** → killed first (no requests/limits set).

---

## 6. Debugging

Check pod events:

```bash
kubectl describe pod <pod>
```

Check container termination reason:

```bash
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

Check resource usage live:

```bash
kubectl top pod
kubectl top node
```

---

## 7. Best Practices

✅ Always set both **requests** and **limits** → prevents cluster starvation.
✅ For latency-sensitive apps → set **requests == limits** → no throttling surprises.
✅ Monitor OOMKills with Prometheus/Grafana → catch memory leaks.
✅ Use **Vertical Pod Autoscaler (VPA)** to adjust requests automatically.
✅ Use **HPA (Horizontal Pod Autoscaler)** for CPU-based scaling.
