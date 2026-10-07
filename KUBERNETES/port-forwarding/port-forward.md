`kubectl port-forward` command creates a secure, temporary network tunnel between your local machine and a resource inside your Kubernetes cluster. This allows you to interact with internal cluster services—like databases, APIs, or administration dashboards—locally via localhost without exposing them to the public internet.

```bash
kubectl port-forward [TYPE/]NAME [LOCAL_PORT:]REMOTE_PORT [...[LOCAL_PORT_N:]REMOTE_PORT_N] [options]
```

* Forward one or more local ports on your machine to a port on a **pod**, **deployment**, or **service** in Kubernetes.
* Useful for debugging, local testing, when you don't have direct access to cluster nodes and securely accessing in-cluster services without exposing them publicly.
* We can expose our application in K8S in two main ways: **temporarily via port-forwarding** or **permanently via a Service**. Here we focus on **port-forwarding**.



* `TYPE/NAME` → Resource type (`pod`, `deployment`, `service`, etc.) and name.
* `LOCAL_PORT` → Port on your local machine.
* `REMOTE_PORT` → Port inside the pod/service.

If only one port is given, local and remote ports are the same.
If `LOCAL_PORT:` is omitted, local port = remote port.

```bash
kubectl port-forward pod/web-server-pod 8080:80
```
* Maps local port `8080` to Pod’s container port `80`.
* **kubectl** creates a **tunnel** from your local machine → cluster node → Pod.
* This allows you to access the Pod **without exposing it externally**.
* Open a browser and go to: `http://localhost:8080`
* To stop port forwarding, press **CTRL + C**.

* API server forwards traffic → the **node** running the Pod → the Pod’s container port 80.
* All communication is **over a single HTTP/HTTPS connection** (tunnel).

### Commands

```bash
kubectl port-forward pod/my-pod 8080:80 #localhost:8080  →  Pod:80
kubectl port-forward svc/my-service 8080:80 #localhost:8080 → Service:80 → one of its Pods
kubectl port-forward deployment/my-deployment 8080:80 
kubectl port-forward -n dev pod/my-pod 8080:80
kubectl port-forward -n dev svc/my-service 8080:80
kubectl port-forward svc/my-service 8080:80 --address 127.0.0.1
kubectl port-forward svc/my-service 8080:80 --address 127.0.0.1,192.168.1.10
kubectl port-forward svc/my-service 8080:80 --address 0.0.0.0
kubectl port-forward service/myservice 8443:https #Access HTTPS service by name
kubectl port-forward pod/mongo-0 27017:27017
```

---

### FLAGS

##### `--address`
* List of addresses to bind on (default `localhost`).
* Accepts IP addresses or `localhost`.
  ```bash
  kubectl port-forward --address 0.0.0.0 pod/mypod 8888:5000
  ```
* Listens on **all interfaces (0.0.0.0)**, so external clients can connect.
* When you want to expose a pod port to other machines (not just localhost).
* Example: Allow teammates to access a local-forwarded service from their browsers.

---

##### `--pod-running-timeout`
* **Description**: How long to wait for a pod to be in `Running` state before failing. Default = `1m`.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --pod-running-timeout=2m
  ```
* Waits up to **2 minutes** for the pod to start.
* Useful in CI/CD pipelines where pods may take extra time to initialize before port-forwarding.

---

##### `-h, --help`
  ```bash
  kubectl port-forward --help
  ```
* Displays all available options.

---

##### `--as`
* Run command as another Kubernetes user.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --as admin
  ```
* Impersonates user `admin`.
* Testing RBAC permissions by simulating another user’s access.

---

##### `--as-group`
* Run as a specific group (can repeat).
  ```bash
  kubectl port-forward pod/mypod 8080:80 --as-group=dev-team
  ```
* Runs with group `dev-team`.
* Validate group-level permissions (e.g., dev-team vs ops-team).

---

##### `--as-uid`
* Run command as a specific UID.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --as-uid=1001
  ```
* Impersonates a UID directly.
* Advanced RBAC or debugging scenarios where UID matters.

---

##### `--cache-dir`
* Default kubeconfig cache directory.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --cache-dir=/tmp/kube-cache
  ```
* When using a temporary filesystem or in CI/CD environments where `$HOME` is not writable.

---

##### `--certificate-authority`
* Path to custom CA cert.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --certificate-authority=/etc/k8s/ca.crt
  ```
* Accessing clusters with private CAs.

---

##### `--client-certificate` + `--client-key`
* TLS client authentication files.
  ```bash
  kubectl port-forward pod/mypod 8080:80 \
    --client-certificate=/etc/k8s/client.crt \
    --client-key=/etc/k8s/client.key
  ```
* When API server requires **mutual TLS authentication**.

---

##### `--cluster`
* Specify cluster from kubeconfig.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --cluster=dev-cluster
  ```
* Targets the `dev-cluster`.
* If kubeconfig has multiple clusters.

---

##### `--context`
* Specify kubeconfig context.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --context=staging
  ```
* Uses `staging` context.
* Switching between clusters/namespaces quickly.

---

##### `--disable-compression`
* Disable server response compression.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --disable-compression
  ```
* Turns off response gzip.
* Debugging network issues where compression interferes.

---

##### `--insecure-skip-tls-verify`
* Skip TLS certificate verification.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --insecure-skip-tls-verify
  ```
* Ignores invalid/self-signed certs.
* Quick debugging in dev environments.

---

##### `--kubeconfig`
* Path to a kubeconfig file.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --kubeconfig=/tmp/custom-kubeconfig
  ```
* Uses `/tmp/custom-kubeconfig`.
* Running with alternate kubeconfig files.

---

##### `--kuberc`
* Path to kuberc preferences file.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --kuberc=/etc/kube/kuberc
  ```
* Advanced configs; can disable with `KUBECTL_KUBERC=false`.

---

##### `--match-server-version`
* Require server/client version match.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --match-server-version
  ```
* Avoids API incompatibility issues.

---

###### `-n, --namespace`
* Set namespace.
  ```bash
  kubectl port-forward -n mynamespace pod/mypod 8080:80
  ```
* Forwards from a pod in namespace `mynamespace`.
* When pod is not in `default`.

---

##### `--password` / `--username`
* Basic authentication credentials.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --username=user --password=pass
  ```
* Legacy clusters still using basic auth.

---

##### `--profile` + `--profile-output`
* Performance profiling.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --profile=cpu --profile-output=pf-profile.pprof
  ```
* Debugging kubectl performance.

---

##### `--request-timeout`
* Timeout for API requests.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --request-timeout=30s
  ```
* Prevent long hangs if API server is slow.

---

##### `-s, --server`
* API server address.
  ```bash
  kubectl port-forward pod/mypod 8080:80 -s https://1.2.3.4:6443
  ```
* Direct connect without kubeconfig.

---

### Storage Driver Options

* `--storage-driver-buffer-duration`
* `--storage-driver-db`
* `--storage-driver-host`
* `--storage-driver-password`
* `--storage-driver-secure`
* `--storage-driver-table`
* `--storage-driver-user`

```bash
kubectl port-forward pod/mypod 8080:80 \
  --storage-driver-host=localhost:8086 \
  --storage-driver-db=metricsdb \
  --storage-driver-user=admin --storage-driver-password=secret
```

---

### `--tls-server-name`
* Override TLS SNI.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --tls-server-name=mycluster.local
  ```
* When server cert CN doesn’t match hostname.

---

### `--token`
* Bearer token authentication.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  ```
* Service account or automation scripts.

---

### `--user`
* Specify kubeconfig user.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --user=devuser
  ```
* When kubeconfig has multiple users.

---

### `--version`
* Print version or set compatibility.
  ```bash
  kubectl port-forward --version
  kubectl port-forward --version=raw
  ```
* Debugging kubectl-client mismatch.

---

### `--warnings-as-errors`
* Treat warnings as errors.
  ```bash
  kubectl port-forward pod/mypod 8080:80 --warnings-as-errors
  ```
* Strict CI/CD pipelines where warnings must fail.
