### References:-
- [Day 23: DEEP-DIVE into Kubernetes Health Probes | Readiness vs Liveness vs Startup](https://www.youtube.com/watch?v=ANSBnfil75Y&ab_channel=CloudWithVarJosh)
- [Kubernetes Concepts: Understanding Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- [Kubernetes Tasks: Configure Liveness, Readiness, and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- https://codefresh.io/learn/kubernetes-management/6-types-of-kubernetes-health-checks-and-using-them-in-your-cluster/
- https://spacelift.io/blog/kubernetes-readiness-probe
- https://spacelift.io/blog/kubernetes-liveness-probe
* [Day 18/40 - Health Probes in kubernetes](https://youtu.be/x2e6pIBLKzw)


---

![Alt text](/images/23a.png)

* Health probes are used to check the status of applications running inside pods. 
* These probes help Kubernetes ensure that only healthy pods are receiving traffic, and unhealthy pods are either given time to recover or restarted as necessary. 
* The **kubelet** is responsible for performing these probes at defined intervals.
* Probe==Condition==Checking

* **Types of Health Probes**

![Alt text](/images/23b.png)

<br>

#### **1. Readiness Probes (RP)**
  * Determines if the application is **ready** to handle traffic. If this probe fails, the Pod is marked as **"Not Ready"** and is removed from Service endpoints(Service not LB trafic to it), but the container itself is not restarted.
  * Checks if a container is **ready to start accepting traffic**.
  * Readiness probes run throughout a Kubernetes pod's entire lifecycle.
  * Is mark entire pod not ready means all container in it not able to server traffic.
  * Prevents routing traffic to containers that are temporarily unable to serve requests due to initialization delays or resource constraints.
  * When the probe passes, the pod is added back into the load balancer and traffic resumes.
  * This ensures that only healthy and fully initialized containers receive incoming requests.
  * Mark Entire pod(all containers) Unready
     ```yaml
      readinessProbe:
        httpGet:
          path: /readyz
          port: 8080
        initialDelaySeconds: 5  # Wait 5 seconds after container starts before probing
        periodSeconds: 10       # Probe every 10 seconds
     ```
      - **Explanation:**
        - Checks if the application is ready to serve traffic.
        - HTTP GET request is sent to /readyz on port 8080.
        - Starts after an initial delay of 5 seconds.
        - If probe fails, the pod is temporarily removed from Service endpoints (no restart).
        - Once probe passes, pod starts receiving traffic.
    - **Use Case**:
      - A database connection might temporarily fail. During this time, the readiness probe ensures that traffic is not sent to the affected pod.
      - Wait for dependencies like database, cache, message brokers to be ready.
      - Prevent traffic during rolling updates until the new pod is healthy.

---
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: example-pod
    labels:
      app: nginx
  spec:
    containers:
    - name: example-container
      image: nginx
      ports:
      - containerPort: 80
      command: ["/bin/bash","-c"]
      args:
      - |
        echo 'Mahin Raza' > /usr/share/nginx/html/testpath;
        nginx -g "daemon off;";
      readinessProbe:
        httpGet:
          path: /testpath
          port: 80
        initialDelaySeconds: 15
        periodSeconds: 10
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: nginx-svc
  spec:
    selector:
      app: nginx
    ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  ```

  ```bash
  controlplane:~$ kubectl describe pod example-pod | grep -i readiness

  Readiness:      http-get http://:80/testpath delay=15s timeout=1s period=10s #success=1 #failure=3
  ```
  ```bash
  controlplane:~$ kubectl get ep

  Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
  NAME         ENDPOINTS         AGE
  kubernetes   172.30.1.2:6443   20d
  nginx-svc    192.168.1.5:80    3m23s
  ```
  ```bash
  controlplane:~$ kubectl exec -it example-pod -- rm -f /usr/share/nginx/html/testpath
  ```
  ```bash
  controlplane:~$ kubectl describe pod example-pod | grep -i -A20 events
   
  Events:
    Type     Reason     Age   From               Message
    ----     ------     ----  ----               -------
    Normal   Scheduled  3m8s  default-scheduler  Successfully assigned default/example-pod to node01
    Normal   Pulling    3m8s  kubelet            Pulling image "nginx"
    Normal   Pulled     3m7s  kubelet            Successfully pulled image "nginx" in 1.794s (1.794s including waiting). Image size: 59774010 bytes.
    Normal   Created    3m6s  kubelet            Created container: example-container
    Normal   Started    3m6s  kubelet            Started container example-container
    Warning  Unhealthy  4s    kubelet            Readiness probe failed: HTTP probe failed with statuscode: 404
  ```
  ```bash
  controlplane:~$ kubectl get ep

  Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
  NAME         ENDPOINTS         AGE
  kubernetes   172.30.1.2:6443   20d
  nginx-svc                      4m53s
  ```
  ```bash
  controlplane:~$ curl 10.111.46.157
  curl: (7) Failed to connect to 10.111.46.157 port 80 after 0 ms: Couldn't connect to server
  ```

---

  * **Example 1: HTTP Readiness Probe**
    * Checks if the web server responds with **HTTP 200** on `/testpath` at port `8080`.
    * For web servers or APIs where health is determined by an HTTP response.
      ```yaml
      apiVersion: v1
      kind: Pod
      metadata:
        name: example-pod
        labels:
          app: nginx
      spec:
        containers:
        - name: example-container
          image: nginx
          ports:
          - containerPort: 80
          command: ["/bin/bash","-c"]
          args:
          - |
            echo 'Mahin Raza' > /usr/share/nginx/html/testpath;
            nginx -g "daemon off;";
          readinessProbe:
            httpGet:
              path: /testpath
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
      ```

<br>

  * **Example 2: TCP Readiness Probe**
    * Kubernetes checks if it can establish a TCP connection on port `8080`.
    * For applications that expose a port but don’t use HTTP, such as databases or message queues.
      ```yaml
      apiVersion: v1
      kind: Pod
      metadata:
        name: example-pod
      spec:
        containers:
        - name: example-container
          image: nginx
          ports:
          - containerPort: 80
          readinessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
      ```

<br>

  * **Example 3: Command Readiness Probe**
    * A custom script `check-script.sh` or commands runs inside the container to determine readiness.
      * The script must return:
        * `0` → ready
        * Non-zero → not ready
    * For applications that require custom logic (e.g., checking a file, database connection, or service state).
      ```yaml
      apiVersion: v1
      kind: Pod
      metadata:
        name: my-app-pod
      spec:
        containers:
        - name: my-app-container
          image: nginx
          ports:
          - containerPort: 80
          readinessProbe:
            exec:
              command:
              - /bin/sh
              - -c
              - check-script.sh
            initialDelaySeconds: 20
            periodSeconds: 15
      ```

  * **Common Causes of Readiness Probe Failures — Summary**
    1. **Slow Startup**
       * App takes too long to initialize.
       * **Fix:** Increase `initialDelaySeconds` or optimize startup.
    
    2. **Dependencies Not Ready**
       * DB, cache, or API not available yet.
       * **Fix:** Use init containers, retry logic, or dependency checks.
  
    3. **Wrong Probe Configuration**
       * Incorrect path/port or invalid response code.
       * **Fix:** Verify HTTP path, port, and probe settings.

    4. **Application Errors**
       * Crashes, exceptions, or config failures.
       * **Fix:** Check logs, fix bugs, correct configuration.

    5. **Resource Issues**
       * CPU/memory too low → app becomes slow/unresponsive.
       * **Fix:** Increase resource limits/requests, optimize resource usage.

    6. **Probe Conflicts**
       * Liveness kills container before readiness passes.
       * **Fix:** Tune probe intervals independently, separate roles.

    7. **Cluster Problems**
       * Network, DNS, or kubelet issues.
       * **Fix:** Inspect node logs, check connectivity, resolve cluster pressure.

<br>

#### **2. Liveness Probes (LP)**
  * The **kubelet** uses liveness probes to know when to restart a container. 
  * Detects and restarts applications:
    * Deadlocks (when an application is stuck and not progressing)
    * Crashes or unresponsive processes
    * Memory leaks or infinite loops causing hangs
  * For example, liveness probes could catch a deadlock, where an application is running, but unable to make progress. Restarting a container in such a state can help to make the application more available despite bugs.
  * Checks if a container is **alive and functioning correctly**.
  * When the liveness probe fails, **the pod is restarted**.
  * Helps recover from **irrecoverable failures**, such as deadlocks or unresponsive applications.
     ```yaml
      livenessProbe:
        exec:
          command:
          - cat
          - /tmp/healthy
        initialDelaySeconds: 3  # Start checking 3 seconds after the container starts
        periodSeconds: 5        # Check every 5 seconds
     ```
     - **Explanation:**
        - Verifies if the application is still alive.
        - Executes `cat /tmp/healthy` inside the container.
        - If this command fails (e.g., file missing), the liveness probe fails.
        - **Kubelet will restart the container automatically** to recover from the failure.

---
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    app: nginx
spec:
  containers:
  - name: example-container
    image: nginx
    ports:
    - containerPort: 80
    command: ["/bin/bash","-c"]
    args:
    - |
      echo 'Mahin Raza' > /usr/share/nginx/html/testpath;
      nginx -g "daemon off;";
    livenessProbe:
      httpGet:
        path: /testpath
        port: 80
      initialDelaySeconds: 15
      periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```
```bash
controlplane:~$ kubectl exec -it example-pod -- rm -f /usr/share/nginx/html/testpath
```
```bash
controlplane:~$ kubectl get pods -w
NAME          READY   STATUS    RESTARTS      AGE
example-pod   1/1     Running   1 (33s ago)   93s
example-pod   1/1     Running   2 (2s ago)    2m2s
```
```bash
controlplane:~$ kubectl describe pod example-pod | grep -i -A20 events
Events:
  Type     Reason     Age                  From               Message
  ----     ------     ----                 ----               -------
  Normal   Scheduled  2m24s                default-scheduler  Successfully assigned default/example-pod to node01
  Normal   Pulled     2m22s                kubelet            Successfully pulled image "nginx" in 1.561s (1.561s including waiting). Image size: 59774010 bytes.
  Normal   Pulled     83s                  kubelet            Successfully pulled image "nginx" in 1.286s (1.286s including waiting). Image size: 59774010 bytes.
  Normal   Pulling    24s (x3 over 2m24s)  kubelet            Pulling image "nginx"
  Warning  Unhealthy  24s (x6 over 104s)   kubelet            Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    24s (x2 over 84s)    kubelet            Container example-container failed liveness probe, will be restarted
  Normal   Pulled     23s                  kubelet            Successfully pulled image "nginx" in 1.387s (1.387s including waiting). Image size: 59774010 bytes.
  Normal   Created    22s (x3 over 2m22s)  kubelet            Created container: example-container
  Normal   Started    22s (x3 over 2m22s)  kubelet            Started container example-container
```

---

<br>

  * **liveness-http and readiness-http**
    ``` yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: hello
    spec:
      containers:
      - name: liveness
        image: registry.k8s.io/e2e-test-images/agnhost:2.40
        args:
        - liveness
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 3
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
    ```
    * This specific mode (liveness) is designed by Kubernetes for testing probe failures intentionally.
    It will start returning HTTP 500 responses after a short while(10sec) — exactly what your logs show:
      ```bash
      Liveness probe failed: HTTP probe failed with statuscode: 500
      ```
    * So in your case, Kubernetes isn’t misconfigured — it’s behaving correctly based on what the container is doing.
    * That container simulates an app that fails liveness checks on purpose (to test restarts).
    * https://pkg.go.dev/k8s.io/kubernetes/test/images/agnhost#section-readme

<br>

  * **liveness command**

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        test: liveness
      name: liveness-exec
    spec:
      containers:
      - name: liveness
        image: registry.k8s.io/busybox
        args:
        - /bin/sh
        - -c
        - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
        livenessProbe:
          exec:
            command:
            - cat
            - /tmp/healthy
          initialDelaySeconds: 5
          periodSeconds: 5
    ```
    ```bash
    Events:
      Type     Reason     Age                From               Message
      ----     ------     ----               ----               -------
      Normal   Scheduled  76s                default-scheduler  Successfully assigned default/liveness-exec to node01
      Normal   Pulled     72s                kubelet            Successfully pulled image "registry.k8s.io/busybox" in 3.443s (3.443s including waiting). Image size: 1144547 bytes.
      Normal   Created    72s                kubelet            Created container: liveness
      Normal   Started    72s                kubelet            Started container liveness
      Warning  Unhealthy  31s (x3 over 41s)  kubelet            Liveness probe failed: cat: can't open '/tmp/healthy': No such file or directory
      Normal   Killing    31s                kubelet            Container liveness failed liveness probe, will be restarted
      Normal   Pulling    1s (x2 over 76s)   kubelet            Pulling image "registry.k8s.io/busybox"
      Normal   Created    10s (x2 over 84s)  kubelet            Created container: liveness
      Normal   Started    10s (x2 over 84s)  kubelet            Started container liveness
      Normal   Pulled     10s                kubelet            Successfully pulled image "registry.k8s.io/busybox" in 2.743s (2.743s including waiting). Image size: 1144547 bytes.
    ```

  * **liveness-tcp**
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: tcp-pod
      labels:
        app: tcp-pod
    spec:
      containers:
      - name: goproxy
        image: registry.k8s.io/goproxy:0.1
        ports:
        - containerPort: 8080
        livenessProbe:
          tcpSocket:
            port: 3000 #diff port
          initialDelaySeconds: 10
          periodSeconds: 5
    ```
    ```bash
    Events:
      Type     Reason     Age                From               Message
      ----     ------     ----               ----               -------
      Normal   Scheduled  42s                default-scheduler  Successfully assigned default/tcp-pod to node01
      Normal   Pulling    42s                kubelet            Pulling image "registry.k8s.io/goproxy:0.1"
      Normal   Pulled     38s                kubelet            Successfully pulled image "registry.k8s.io/goproxy:0.1" in 3.691s (3.691s including waiting). Image size: 1698862 bytes.
      Normal   Created    17s (x2 over 38s)  kubelet            Created container: goproxy
      Normal   Started    17s (x2 over 38s)  kubelet            Started container goproxy
      Normal   Killing    17s                kubelet            Container goproxy failed liveness probe, will be restarted
      Normal   Pulled     17s                kubelet            Container image "registry.k8s.io/goproxy:0.1" already present on machine
      Warning  Unhealthy  2s (x5 over 27s)   kubelet            Liveness probe failed: dial tcp 192.168.1.9:3000: connect: connection refused
      Normal   Killing    2m43s (x6 over 5m8s)    kubelet            Container goproxy failed liveness probe, will be restarted
      Warning  BackOff    11s (x17 over 3m48s)    kubelet            Back-off restarting failed container goproxy in pod tcp-pod_default(d47824b2-fe67-4ca9-b031-2866850d30ca)
    ```


<br>

#### **3. Startup Probes**
  * Ensures that the container has enough time to initialize the application. Until this probe succeeds, **liveness and readiness probes/timers** are not triggered.
  * Used for **legacy or slow-starting applications** that take variable amounts of time to initialize.
  * The `initialDelaySeconds` parameter cannot always capture the correct startup time for such applications. Setting it too high causes unnecessary delays, and too low leads to premature restarts.
  * Useful when the app takes minutes to initialize.
  * When a startup probe is defined, **liveness and readiness probes do not start** until the startup probe succeeds.
  * Once the startup probe succeeds, Kubernetes starts liveness/readiness checks.
     ```yaml
     startupProbe:
      httpGet:
        path: /healthz
        port: 8080
      failureThreshold: 30  # Kubernetes (via Kubelet) will attempt the probe up to 30 times before failing
      periodSeconds: 10     # Probe runs every 10 seconds
     ```
      - **Explanation:**
        - This probe is responsible for determining when the application has successfully started.
        - It sends an HTTP GET request to /healthz on port 8080.
        - It will try every 10 seconds, up to 30 times (total grace period = 300 seconds).
        - If all 30 attempts fail, Kubernetes will mark the pod as failed and stop trying.
      - No restart happens because the app never started properly.
     This configuration ensures the app has **up to 5 minutes** (30 * 10 = 300 seconds) to initialize.

---

### **Why Configure Both Readiness and Liveness Probes?**

While it may seem that configuring only liveness probes is enough, **best practice dictates using both** for the following reasons:
- **Readiness Probes (RP)**:
  - Do not restart a failing pod; they just stop sending traffic to it.
  - This ensures that **transient issues** (e.g., high load or temporary database unavailability) do not unnecessarily trigger a restart.
  - Pods can continue running and recover without interruption.
- **Liveness Probes (LP)**:
  - Designed for **critical, irrecoverable issues** where a restart is the only solution.
  - Ensures that **dead or hung pods are recreated**, preserving application availability.

**Key Insight**:
- Without RP: Traffic may still be sent to pods experiencing temporary failures, degrading user experience.
- Without LP: Pods stuck in fatal states will remain idle and waste resources.

---

### Probe Timer Configuration Parameters

| **Property**          | **Meaning**                                                    | **Default Value** | **Example**                              |
|----------------------|----------------------------------------------------------------|-------------------|------------------------------------------|
| `initialDelaySeconds` | Wait time before first probe starts after container starts     | `0` seconds       | `initialDelaySeconds: 5` → starts after 5 sec |
| `periodSeconds`       | Time interval between probe attempts                           | `10` seconds      | `periodSeconds: 10` → probes every 10 sec   |
| `timeoutSeconds`      | Max wait time for probe response                               | `1` second        | `timeoutSeconds: 2` → fail if no reply in 2 sec |
| `successThreshold`    | No. of consecutive successes needed to mark successful         | `1`               | `successThreshold: 3` → pass after 3 successes |
| `failureThreshold`    | No. of consecutive failures before marking probe as failed     | `3`               | `failureThreshold: 5` → fail after 5 failures  |

---

### **Behavior of RP, LP, and Startup Probes with Multi-Container Pods**

1. **Pod and Container Relationship**:
   - A pod in Kubernetes can host multiple containers.
   - The **pod's status reflects the worst state of any container** within it:
     - Common errors include:
       - **`Error`**: Indicates a general runtime issue (e.g., application crash or misconfiguration).
       - **`ImagePullBackOff`**: Happens when Kubernetes cannot pull the specified container image (e.g., due to incorrect image name or registry authentication issues).
       - **`CrashLoopBackOff`**: Occurs when a container starts, crashes, and continuously restarts in a loop.
       - **`RunContainerError`**: A catch-all for runtime errors (e.g., failure to execute the container command).
     - A pod is marked **"Running"** only when all containers within it are successfully running.

2. **Startup Probe**:
   - Each container's startup probe runs independently.
   - If the startup probe for one container fails, **only that container is affected**, and liveness/readiness probes are not triggered for it. Other containers proceed unaffected.

3. **Readiness Probe**:
   - Readiness probes determine whether the pod is ready to serve traffic.
   - If the readiness probe fails for **one container**, the **entire pod** is marked **"Not Ready"** to ensure no partial or unreliable service is provided.
   - Failed readiness probes only affect traffic routing and do not restart the container.

4. **Liveness Probe**:
   - Liveness probes are container-specific.
   - If the liveness probe fails for one container, **only that container is restarted** by the **Kubelet**, while other containers remain unaffected.


---

### **Kubernetes Health Probes: Comprehensive Comparison**

Here is the revised table with the important words and concepts **bolded** to highlight key details:

| **Aspect**                     | **Startup Probe**                                                                | **Readiness Probe**                                                               | **Liveness Probe**                                                                |
|--------------------------------|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| **Purpose**                    | Ensure **slow-starting apps** are given enough time to start                     | Check if the pod is **ready to receive traffic**                                 | Check if the pod is **alive and functioning properly**                           |
| **When Does It Start?**        | **Immediately** after container starts                                           | Starts **when the pod enters the "Running" state** and **after Startup Probe succeeds (if configured)** | Starts **when the pod enters the "Running" state** and **after Startup Probe succeeds (if configured)** |
| **Failure Behavior**           | Pod is **killed & restarted** after failure threshold is exceeded during startup | Pod is **marked unready** and removed from **Service load balancers**; not restarted | Pod is **killed & restarted** after failure threshold exceeded                   |
| **Effect on Pod Traffic**      | **No direct effect**                                                             | **Stops sending traffic** to the pod                                             | **No direct effect** on traffic                                                  |
| **Common Use Case**            | **Legacy apps**, slow-booting apps with unpredictable startup times              | Apps needing time to **initialize external dependencies or configurations**       | Recover from **stuck apps**, **deadlocks**, or **memory leaks**                  |
| **Recovery Mechanism**         | Pod is **restarted** during initialization                                       | **No restart**; waits for probe to pass                                          | Pod is **restarted**                                                             |
| **Runs Until**                 | Probe **succeeds** → switches control to **RP & LP**                             | Runs **continuously** throughout the pod's lifecycle                             | Runs **continuously** throughout the pod's lifecycle                             |
| **Starts Again After Restart?**| **Yes**                                                                          | **Yes**                                                                          | **Yes**                                                                          |
| **Relation to Service Traffic**| **None**                                                                         | Directly **influences Service endpoints**                                        | **None**                                                                         |
| **Frequency (Default)**        | Configurable (e.g., `periodSeconds`, `failureThreshold`)                          | Configurable (e.g., `initialDelaySeconds`, `periodSeconds`)                      | Configurable (e.g., `initialDelaySeconds`, `periodSeconds`)                      |
| **Mechanisms Supported**       | **HTTP GET**, **TCP Socket**, **Exec Command**                                   | **HTTP GET**, **TCP Socket**, **Exec Command**                                   | **HTTP GET**, **TCP Socket**, **Exec Command**                                   |
| **Best Practices**             | Use for **apps with unpredictable boot times**                                   | **Always** use in production to avoid sending traffic to **unready pods**        | **Always** use to automatically recover from **unrecoverable failures**          |
| **Administrative Benefit**     | Avoid unnecessary **premature restarts** for **slow-start apps**                 | Prevent unnecessary **load and requests** hitting pods that **aren't ready**     | Ensures **automatic recovery** from **failures**                                 |
| **Impact on Resources**        | Uses **CPU/memory** during startup period                                        | Pod consumes resources but doesn't receive traffic if **unready**                | Pod consumes resources until **restarted**                                       |
| **Pod State While Failing**    | Pod **restarts** after failure                                                   | Pod **stays running** but removed from **Service traffic**                       | Pod **restarts** after failure                                                   |
| **Typical Example**            | **Java apps** taking >60s to start, **legacy monoliths**                         | App needs **DB connection** or **configuration loaded** before accepting requests | **Deadlock**, app frozen, **memory leak**, or stuck threads                      |

---

### **Probe Mechanisms**

![Alt text](/images/23c.png)

Kubernetes provides **three mechanisms** for performing health probes:

1. **HTTP GET Requests**:
   - The kubelet sends an HTTP GET request to a specified endpoint + port.
   - **Success**: Status codes 200–399.
   - **Failure**: Any other status code.
   - **Example**:
     ```yaml
     livenessProbe:
       httpGet:
         path: /healthz
         port: 8080
       initialDelaySeconds: 3
       periodSeconds: 5
     ```
     In this case, the app responds with HTTP `200` to indicate health.

2. **TCP Socket**:
   - The kubelet checks if a TCP connection can be established to a specified port.
   - **Success**: Connection is successful.
   - **Failure**: Connection cannot be established.
   - **Example**:
     ```yaml
     readinessProbe:
       tcpSocket:
         port: 3306
       initialDelaySeconds: 10
       periodSeconds: 5
     ```
     This is useful for services like databases that listen on specific ports.

3. **Command Execution**:
   - The kubelet runs a specified command inside the container.
   - **Success**: Command exits with code `0`.
   - **Failure**: Command exits with a non-zero code.
   - **Example**:
     ```yaml
     livenessProbe:
       exec:
         command:
         - cat
         - /tmp/healthy
       initialDelaySeconds: 5
       periodSeconds: 10
     ```
     ```yaml
     livenessProbe:
       exec:
         command: ["cat", "/tmp/healthy"]
       initialDelaySeconds: 5
       periodSeconds: 5
     ```
     In this example, the app creates a `/tmp/healthy` file when healthy. If the file is missing, the probe fails.

4. **gRPC Probe (K8s v1.24+)**
   * Uses gRPC `Health Check Protocol`.
   * Requires the application to implement `grpc.health.v1.Health`.
   ```yaml
   readinessProbe:
     grpc:
       port: 8080
       service: "grpc.health.v1.Health"
   ```

#### Example with All Three Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: myapp:1.0
    ports:
    - containerPort: 8080
    livenessProbe:
      httpGet:
        path: /live
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
    startupProbe:
      httpGet:
        path: /startup
        port: 8080
      failureThreshold: 30
      periodSeconds: 10
```

---

### **Conclusion**
By combining **Startup**, **Readiness**, and **Liveness Probes**, you can:
- Protect slow-starting apps from premature terminations.
- Ensure only **ready** pods receive traffic, enhancing application stability.
- Recover from fatal application issues by restarting pods with **liveness probes**.

These probes allow Kubernetes to dynamically manage the health of your applications, ensuring availability and a better user experience.

---

## Demo: Readiness Probe with Command Execution
**Objective:** Prevent traffic from being sent to the pod until it is fully ready to serve requests.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-probe-demo
spec:
  containers:
  - name: busybox-app
    image: busybox
    command: ["sh", "-c", "touch /tmp/ready; sleep 3600"] # Creates /tmp/ready file and keeps container running for 1 hour
    readinessProbe:
      exec:                       # Runs a command inside the container
        command:
        - cat
        - /tmp/ready               # Command checks if /tmp/ready file exists
      initialDelaySeconds: 5       # Wait 5 seconds before the first probe
      periodSeconds: 5             # Probe runs every 5 seconds
      failureThreshold: 1          # Mark pod as NotReady after 1 failure
```

---

## Explanation:

- `exec`: Executes a command inside the container for readiness check.
- `command`: Runs `cat /tmp/ready`; probe passes if file exists.
- `initialDelaySeconds: 5`: Waits 5 seconds before sending the first probe.
- `periodSeconds: 5`: Probes every 5 seconds to check readiness.
- `failureThreshold: 1`: A single failure marks the pod as **NotReady** immediately.

---

## How to Test:

1. Simulate failure by deleting `/tmp/ready`:

   ```bash
   kubectl exec -it readiness-probe-demo -- rm /tmp/ready
   ```

2. Observe pod readiness status:

   ```bash
   kubectl get pod readiness-probe-demo
   ```

3. Pod will be marked as **NotReady** within ~5 seconds.

---

## How to Recover:

1. Recreate `/tmp/ready`:

   ```bash
   kubectl exec -it readiness-probe-demo -- touch /tmp/ready
   ```

2. Check pod status:

   ```bash
   kubectl get pod readiness-probe-demo
   ```

3. Pod will become **Ready** after the next successful probe (within 5 seconds).

---

## Demo: Liveness Probe with HTTP GET

**Objective:** Restart the pod if it becomes unresponsive or encounters a failure.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-probe-demo
  labels:
    test: liveness
spec:
  containers:
  - name: liveness
    image: registry.k8s.io/e2e-test-images/agnhost:2.40
    args:
    - liveness
    livenessProbe:
      httpGet:
        path: /healthz               # Endpoint to check for health status
        port: 8080                  # Port where the application is running
        httpHeaders:
        - name: Custom-Header       # Custom header name
          value: Awesome            # Custom header value
      initialDelaySeconds: 3        # Wait 3 seconds before starting probes
      periodSeconds: 3              # Run the probe every 3 seconds
      timeoutSeconds: 1             # Wait 1 second for a response before timing out
      failureThreshold: 1           # After 1 failure, restart the container
```

**Explanation:**

- **`livenessProbe`**: Defines the probe to check if the container is alive.
- **`httpGet`**: Specifies that the probe will perform an HTTP GET request.
  - **`path: /healthz`**: The HTTP endpoint used to check the application's health.
  - **`port: 8080`**: The port on which the application is listening.
  - **`httpHeaders`**: Custom headers added to the HTTP request.
    - **`name: Custom-Header`**: Name of the custom header.
    - **`value: Awesome`**: Value of the custom header.
- **`initialDelaySeconds: 3`**: Kubernetes waits 3 seconds after the container starts before initiating the first probe.
- **`periodSeconds: 3`**: The probe runs every 3 seconds.
- **`timeoutSeconds: 1`**: The probe times out if no response is received within 1 second.
- **`failureThreshold: 1`**: The container is restarted if the probe fails once.

**How to Test:**

1. **Deploy the Pod:**
   - Save the YAML configuration to a file, e.g., `liveness-probe-demo.yaml`.
   - Apply the configuration to your Kubernetes cluster:
     ```bash
     kubectl apply -f liveness-probe-demo.yaml
     ```

2. **Verify Pod Status:**
   - Check the status of the pod:
     ```bash
     kubectl get pods liveness-probe-demo
     ```
   - Ensure the pod status is `Running`.

3. **Observe Restart Behavior:**
   - Monitor the pod's events to see if Kubernetes restarts the container:
     ```bash
     kubectl describe pod liveness-probe-demo
     ```
   - Look for events indicating that the liveness probe failed and the container was restarted.

**Expected Outcome:**

- For the first 10 seconds after the container starts, the `/healthz` endpoint returns a status of 200, indicating success.
- After 10 seconds, the `/healthz` endpoint returns a status of 500, indicating failure. **This is how the application in the container is configured**
- The liveness probe detects the failure and restarts the container. 
- This cycle repeats, with the container running for 10 seconds before being restarted.

---

## Demo: Startup Probe with TCP Socket
**Objective:** Demonstrate how a **Startup Probe** ensures that a container is given adequate time to start up before Kubernetes begins liveness or readiness checks.


```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-probe-demo
spec:
  containers:
  - name: tcp-app
    image: ubuntu:latest
    command:
      - sh
      - -c
      - |
        apt update && \
        apt install -y netcat-openbsd && \
        nc -l -p 9444 && \
        sleep 3600
    startupProbe:
      tcpSocket:
        port: 9444            # Checks TCP server accessibility on port 9444
      failureThreshold: 15    # Allows up to 15 failed attempts
      periodSeconds: 5        # Probe runs every 5 seconds
```

---

### **Explanation:**

- **Container:**
  - **Image:** `ubuntu:latest` → Uses Ubuntu base image.
  - **Command:**
    - `apt update && apt install -y netcat-openbsd` → Updates package index and installs **Netcat**, ensuring dependencies are handled.
    - **`nc -l -p 9444` → Starts a TCP server in listening mode on port 9444.**
      - `nc` = Netcat command-line tool.
      - `-l` = Listen mode (server mode).
      - `-p 9444` = Listens on **port 9444**.
      - Effectively simulates an application **waiting for incoming TCP connections**.
    - `sleep 3600` → Keeps the container running for 1 hour after TCP server starts.

- **Startup Probe:**
  - **tcpSocket.port: 9444** → Kubernetes probes port **9444** to check if TCP server is up.
  - **failureThreshold: 15** → Allows up to **15 failed attempts** before marking container as failed.
  - **periodSeconds: 5** → Probe runs **every 5 seconds**.


