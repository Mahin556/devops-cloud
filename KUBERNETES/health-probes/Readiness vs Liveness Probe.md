* **Liveness Probe**
  * Checks if the container is **alive and healthy**.
  * If it fails → Kubernetes **restarts the container**.
  * Used to detect deadlocks, crashes, or unresponsive apps.

* **Readiness Probe**
  * Checks if the container is **ready to serve traffic**.
  * If it fails → Kubernetes **removes the pod from service load balancing**, but does **not restart** it.
  * Ensures only healthy pods receive client requests.
