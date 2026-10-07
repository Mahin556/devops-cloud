## 🔹 Memory vs CPU limits difference

* **Memory Limit exceeded** →
  The container tries to use *more RAM* than its limit → the Linux kernel’s **OOM killer** terminates the process.
  👉 Result: Pod gets killed with `OOMKilled`.

* **CPU Limit exceeded** →
  The container *cannot* use more CPU than allowed → but instead of killing it, the **scheduler enforces throttling**.

---

## 🔹 What is CPU Throttling?

CPU throttling = the kernel scheduler **slows down your container’s CPU usage** so it *never goes beyond* the CPU limit you set.

Example:

```yaml
resources:
  limits:
    cpu: "500m"
```

* `500m` = half a CPU core.
* If the container tries to use **1 full CPU**, Kubernetes tells the Linux kernel: *“Don’t give it more than 0.5 CPU.”*
* The kernel enforces this by pausing the container’s execution periodically → effectively making it slower.

---

## 🔹 Real-world analogy

Imagine:

* Memory = **a cup size**. If you pour more liquid than the cup can hold → it spills (OOMKill).
* CPU = **a tap flow control**. You can only get water at a limited flow rate. You won’t get more, but the tap won’t break — it just gives you water slower.

---

## 🔹 Impact of CPU throttling

* App **slows down**, but doesn’t crash.
* If your app is CPU-intensive (e.g., image processing, ML, heavy computation), throttling may cause **latency** or **timeouts**.
* For web apps, throttling can mean **slower response times** but the Pod stays alive.

### References
- https://devopscube.com/kubernetes-deployment-tutorial/