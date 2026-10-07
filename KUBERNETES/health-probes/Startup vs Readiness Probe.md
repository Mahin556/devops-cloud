* **Startup Probe**
  * Runs **only once** during container startup.
  * Gives slow or legacy apps extra time to initialize.
  * Delays liveness and readiness probes until startup succeeds.
  * Prevents Kubernetes from killing the container too early.

* **Readiness Probe**
  * Runs **continuously** after startup.
  * Checks if the pod is **ready to receive traffic**.
  * If it fails → pod is removed from Service endpoints (no traffic sent).
