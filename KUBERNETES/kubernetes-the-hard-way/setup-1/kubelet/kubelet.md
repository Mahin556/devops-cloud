# Kubelet

## Objectives

A container runtime alone can't join a cluster or accept work from a control plane. That's kubelet's job. In this lesson, you'll install kubelet, the node agent that bridges Kubernetes and the container runtime.

* Understand kubelet's role within a Kubernetes cluster
* Install and configure kubelet from scratch
* Observe how kubelet interacts with containerd via the CRI (Container Runtime Interface)
* Understand the relationship between Pods and containers
* Run Pods using kubelet without an API server
* Learn basic debugging techniques for kubelet

By the end of this lesson, you'll have kubelet running standalone, managing Pods without a control plane.

--- 

## What is kubelet?

kubelet is the primary node agent that runs on every worker node in a Kubernetes cluster. As one of the core components that makes Kubernetes work, it acts as the bridge between the Kubernetes control plane and the container runtime on each node.

kubelet operates in a continuous reconciliation loop:

* Watches for Pod specifications from the API server
* Compares the desired state (what should be running) with the actual state (what is running)
* Takes action to bring the actual state in line with the desired state
* Reports the current status back to the control plane

In essence, kubelet is the "hands and feet" of Kubernetes on each node: it takes declarative Pod specifications from the control plane and makes them a reality by managing containers on the worker nodes.

However, kubelet doesn't run containers directly. Instead, it delegates this responsibility to a container runtime like [containerd](https://containerd.io/) or [CRI-O](https://cri-o.io/). To support multiple runtimes and provide flexibility in runtime selection, kubelet communicates with these runtimes through the [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/).

> **Note**
>
> 🔜 The CRI will be discussed in detail later in this lesson.

---

## Installing kubelet

Download and install kubelet:

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kubelet"

sudo install -m 755 kubelet /usr/local/bin
```

Download the systemd unit file for kubelet:

```bash
sudo wget -O /etc/systemd/system/kubelet.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/02-worker-node/02-kubelet/__static__/kubelet.service?v=1777378794
```
```bash
[Unit]
Description=Kubernetes Kubelet
Documentation=https://kubernetes.io
After=containerd.service
Requires=containerd.service

[Service]
Type=notify

ExecStart=/usr/local/bin/kubelet --config-dir=/var/lib/kubelet/config.d/

ExecStartPre=-/bin/mkdir -p /var/lib/kubelet/config.d/

Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

With kubelet installed, you can now configure it.

> **Note**
>
> 💡 Kubelet supports merging multiple configuration files, allowing you to separate different configuration concerns. Files are merged in alphabetical order, so numbering prefixes (like 50-, 70-, 99-) control the merge order.

For now, you only need to configure how kubelet communicates with the container runtime.

### `/var/lib/kubelet/config.d/99-cri.conf`

```bash
sudo mkdir -p /var/lib/kubelet/config.d
sudoedit /var/lib/kubelet/config.d/99-cri.conf
```

```yaml
cat << EOF > /var/lib/kubelet/config.d/99-cri.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
cgroupDriver: systemd
EOF
```

> **Note**
>
> 💡 The cgroup driver setting was discussed in the previous lesson.

Start the kubelet service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
sudo systemctl status kubelet --no-pager
```

---

## Kubelet Authentication and Authorization

kubelet exposes an HTTP API endpoint (typically on port 10250) that allows the Kubernetes API server and other components to interact with it.

This endpoint provides access to:

* Pod logs and exec sessions
* Node metrics and health information

Normally, this endpoint is secured using TLS and authentication/authorization mechanisms. However, for the purposes of this lesson, you will disable authentication and authorization to simplify the setup.

> **Important**
>
> ⚠️ Do NOT disable authentication and authorization in production environments.

Configure kubelet to disable authentication and authorization.

![alt text](image.png)

### `/var/lib/kubelet/config.d/70-authnz.conf`

```yaml
cat << EOF > /var/lib/kubelet/config.d/70-authnz.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false

authorization:
  mode: AlwaysAllow
EOF
```

Restart the kubelet service to apply the configuration changes:

```bash
sudo systemctl restart kubelet
sudo systemctl status kubelet --no-pager
```

Verify that the kubelet API endpoint is accessible:

```bash
curl -k https://localhost:10250/healthz
```

---

# Static Pods

Static Pods are Pods managed directly by kubelet on a specific node rather than by the Kubernetes API server.

Unlike regular Pods that are created and managed through the cluster's control plane, static Pods are defined by placing Pod manifest files in a directory that kubelet monitors.

When kubelet finds a Pod manifest in the static Pod directory, it automatically creates and manages that Pod. If the Pod crashes or stops, kubelet automatically restarts it (through the container runtime).

kubelet also creates a mirror Pod in the Kubernetes API server for each static Pod. This mirror Pod allows you to see the static Pod when you run `kubectl get pods`, but you cannot control the static Pod through the API server: only kubelet can manage it directly.

Static Pod functionality is disabled by default and needs to be enabled by configuring kubelet.

![alt text](image-1.png)

---

# Enabling Static Pods

Create the static Pod directory:

```bash
sudo mkdir -p /etc/kubernetes/manifests
```

Configure kubelet to monitor the static Pod directory by creating a configuration file in the kubelet drop-in directory.

### `/var/lib/kubelet/config.d/50-static-pods.conf`

```yaml
cat << EOF > /var/lib/kubelet/config.d/50-static-pods.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

staticPodPath: /etc/kubernetes/manifests
EOF
```

Restart the kubelet service to apply the configuration changes:

```bash
sudo systemctl restart kubelet
```

---

# Creating Your First Static Pod

Create your first static Pod by deploying a simple application called **podinfo** to verify everything works correctly.

> **Note**
>
> 💡 podinfo will be the go-to example application throughout this course.

Create the Pod manifest.

### `/etc/kubernetes/manifests/podinfo.yaml`

```yaml
mkdir -p /etc/kubernetes/manifests/

cat << EOF > /etc/kubernetes/manifests/podinfo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: podinfo
spec:
  hostNetwork: true
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
      ports:
        - containerPort: 9898
EOF

rm /etc/kubernetes/manifests/podinfo.yaml
```

> **Note**
>
> 💡 Notice `hostNetwork: true` in the Pod manifest.
>
> This makes the Pod use the host's network namespace instead of creating its own. The Pod shares the host's IP address, so port 9898 is directly accessible on localhost.
>
> This configuration is common for static Pods that need direct access from the host.

> **Important**
>
> ⚠️ Due to their nature, static Pods cannot reference other Kubernetes API objects like Secrets, ConfigMaps, or ServiceAccounts.
>
> They can only use resources available directly on the node, such as hostPath or emptyDir volumes.

Verify that podinfo is running by checking if it appears in the list of Pods (via the kubelet API):

```bash
curl -sfk https://localhost:10250/pods | jq '.items[0].metadata'
```

> **Note**
>
> 💡 Notice the Pod name is **podinfo-worker**.
>
> Static Pods automatically have the node name appended to ensure uniqueness across the cluster.

Since the Pod is running on the host network, it can be accessed directly from the host.

Verify that the application is working correctly:

```bash
curl http://localhost:9898 | jq
```

---

# Kubernetes Namespace in containerd

Here is an interesting bit: even though the Pod is running, you won't see it when you list containers (with tools like nerdctl or ctr):

```bash
sudo nerdctl ps
sudo ctr container ls
```

This happens because containerd organizes containers into namespaces (similar to Kubernetes), and Kubernetes uses the **k8s.io** namespace by default.

You can verify this by running:

```bash
sudo ctr namespace ls
```

To see containers running in the **k8s.io** namespace, use the `--namespace` flag:

```bash
sudo nerdctl ps --namespace k8s.io
sudo ctr --namespace k8s.io container ls
```

---

# Container Runtime Interface (CRI)

The Container Runtime Interface (CRI) is a gRPC API that defines a standard interface for kubelet to interact with container runtimes. It enables kubelet to work with any CRI-compatible container runtime, without runtime-specific code compiled into kubelet.

Many container runtimes (such as containerd and CRI-O) implement the CRI natively, while others (like Docker) require a shim layer to bridge the gap between kubelet and the runtime.

Unlike other specifications mentioned earlier (OCI, CNI), which are Kubernetes-agnostic, the CRI is part of the Kubernetes project. Due to Kubernetes' dominance in container orchestration, many container runtimes now implement CRI natively for seamless integration.

In the early days of Kubernetes, Docker was the only container runtime available. There was no CRI, so kubelet was tightly coupled to Docker.

When CRI was introduced, the Docker implementation was moved to a shim layer (often called dockershim).

As the ecosystem (and Docker itself) adopted alternate container runtimes (containerd, CRI-O), the need for dockershim became less critical, and it was deprecated in Kubernetes v1.20, removed in Kubernetes v1.24.

That doesn't mean you can't use Docker with Kubernetes anymore. If you really-really want to use Docker, you can install **cri-dockerd** which is essentially dockershim with a different name.

![alt text](image-2.png)
![alt text](image-3.png)
---

# CRI API

The CRI API consists of two main services:

* RuntimeService: Manages pod sandboxes and containers (create, start, stop, remove, etc.)
* ImageService: Manages container images (pull, list, remove, etc.)

When kubelet needs to:

* Create a pod: It calls the CRI **RunPodSandbox** method
* Start a container: It calls the CRI **CreateContainer** and **StartContainer** methods
* Pull an image: It calls the CRI **PullImage** method
* Get pod status: It calls the CRI **PodSandboxStatus** method

A pod sandbox is a shared environment in which containers of a pod run, filling the conceptual gap between the Kubernetes pod abstraction and the container runtime. When kubelet starts a Pod, it creates a pod sandbox first by calling the appropriate gRPC method. Once the sandbox is created, kubelet launches the pod's containers in the sandbox.

What a pod sandbox actually entails and how it is managed is an implementation detail of the container runtime.

Traditional container runtimes (like Docker and containerd) that run containers as isolated processes usually create a pause container to set up the sandbox. This is necessary, because Linux namespaces require a running process to exist (well, in most of the cases). The pause container is a lightweight container that runs a single process, typically a sleep command, which keeps the container running indefinitely, holding the namespaces and keeping the sandbox alive.

This is why you see pause containers when you list the running containers:

```bash
sudo ctr --namespace k8s.io container ls
```

Not all runtimes require a pause container though. For example, VM-based runtimes (like Kata Containers or Firecracker) do not require a pause container: the sandbox is the VM itself encapsulating all containers of the pod.

---

# Why "Pod Sandbox"?

In early Kubernetes versions (pre-CRI, 2014–2015), kubelet was tightly coupled to Docker.

Docker itself didn’t provide a way to directly create a shared pod environment (to run multiple containers in).

The workaround was to run a "pause" container first.

This container did nothing except sleep forever. It created and held the Linux namespaces. Other containers in the pod were started in the same namespaces via Docker's `--net=container:<id>` flag.

When Kubernetes grew beyond Docker and the CRI was born, it needed generic abstraction for describing the shared environment of containers in a pod.

"Pause container" wasn't an accurate term anymore, because:

* Not every runtime uses a container to hold namespaces
* Some runtimes can create namespaces without any long-running process

Thus the term **pod sandbox** was introduced into the CRI specification.

Docker and containerd implement pod sandboxes with a pause container to this day, but the spec allows runtimes to implement their own pod sandbox mechanism.

---

# Kubelet (Part 3)

---

# Working with CRI Tools

When working with containers in a Kubernetes environment, it's important to understand the different tools and interfaces:

* **ctr and nerdctl:** These tools interact directly with containerd's native API
* **crictl:** This tool uses CRI, the same interface that kubelet uses
* **kubelet:** Uses CRI to communicate with the container runtime

---

# Installing crictl

crictl is the official CLI tool for interacting with CRI-compatible container runtimes. It's designed to help debug and inspect containers and images managed by kubelet.

Download and install crictl:

```bash
CRICTL_VERSION=v1.34.0

curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION?}/crictl-${CRICTL_VERSION?}-linux-amd64.tar.gz"

sudo tar xzvof "crictl-${CRICTL_VERSION?}-linux-amd64.tar.gz" -C /usr/local/bin
```

Configure crictl to use containerd's CRI socket.

### `/etc/crictl.yaml`

```yaml
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF
```

```bash
sudoedit /etc/crictl.yaml
```

> **Note**
>
> 💡 kubelet uses this same socket to communicate with containerd.

---

# Using crictl

Now that crictl is installed and configured, you can use it to interact with containers the same way kubelet does.

> **Note**
>
> 💡 Unlike ctr and nerdctl, crictl doesn't need a `--namespace` flag because it uses the CRI, which always operates in the Kubernetes context.

List all Pods (similar to kubectl get pods but directly from the runtime):

```bash
sudo crictl pods
```

List all containers:

```bash
sudo crictl ps -a
```

> **Note**
>
> 💡 Notice you don't see any pause containers here.
>
> CRI doesn't expose them as separate containers. They're an implementation detail of how containerd creates pod sandboxes.

List all images:

```bash
sudo crictl images
```

Get detailed information about a pod:

```bash
# First get the pod ID
POD_ID=$(sudo crictl pods -q --name podinfo-worker)

# Then get pod details
sudo crictl inspectp $POD_ID
```

Execute a command in a container:

```bash
# Get container ID
CONTAINER_ID=$(sudo crictl ps -q --name podinfo)

# Execute a command
sudo crictl exec "$CONTAINER_ID" /bin/sh -c "ps aux"
```

View container logs:

```bash
sudo crictl logs $CONTAINER_ID
```

> **Note**
>
> 💡 Notice that crictl commands are very similar to kubectl commands, but they operate directly on the container runtime level.

---

# kubeletctl

kubeletctl is a command-line tool that provides direct access to the kubelet API.

It's useful for debugging and inspecting kubelet instances, querying pod information, retrieving logs, and exploring kubelet's internal state without requiring a full Kubernetes cluster setup.

> **Note**
>
> 💡 kubeLETctl is different from kubectl, the CLI tool for Kubernetes.

---

# Installing kubeletctl

Download and install kubeletctl:

```bash
KUBELETCTL_VERSION=v1.13

curl -fsSLO "https://github.com/cyberark/kubeletctl/releases/download/${KUBELETCTL_VERSION?}/kubeletctl_linux_amd64"

sudo install -m 755 kubeletctl_linux_amd64 /usr/local/bin/kubeletctl
```

---

# Using kubeletctl

With kubeletctl installed, you can perform various operations.

Check the merged configuration:

```bash
kubeletctl configz | jq
```

List all Pods:

```bash
kubeletctl pods
```

Retrieve container logs:

```bash
kubeletctl containerLogs -p podinfo-worker -c podinfo
```

Execute a command in a container:

```bash
kubeletctl exec "ls /" -p podinfo-worker -c podinfo
```

> **Note**
>
> 💡 This demonstrates another important function of kubelet: when you run kubectl logs or kubectl exec, the API server forwards the request to the kubelet on the node where the Pod is running.

---

# Summary

In this lesson, you learned about kubelet, the primary node agent that runs on every worker node in a Kubernetes cluster.

## Key takeaways

* **Control plane bridge:** kubelet acts as the essential link between the Kubernetes control plane and the container runtime, translating API server instructions into container operations
* **Reconciliation loop:** Continuously watches for Pod specifications, compares desired vs actual state, and takes corrective actions to maintain cluster consistency
* **CRI delegation:** Doesn't run containers directly but communicates with container runtimes like containerd through the Container Runtime Interface (CRI)
* **Static Pods:** Enables running critical cluster components directly on nodes before the control plane becomes available, with automatic restart capabilities
* **API endpoint:** Provides an HTTP interface on port 10250 for log access, metrics, and container execution, essential for cluster operations

With kubelet now running and managing static Pods, you have established the node-level foundation for Kubernetes workload management.

---

# Additional Resources

- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/
- https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#bootstrap-tokens
- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/setup/best-practices/certificates/
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/
- https://kubespec.dev/kubernetes/v1/Node
- https://kubespec.dev/kubernetes/v1/Secret
- https://kubespec.dev/kubernetes/certificates.k8s.io/v1/CertificateSigningRequest
- https://kubespec.dev/kubernetes/rbac.authorization.k8s.io/v1/ClusterRoleBinding