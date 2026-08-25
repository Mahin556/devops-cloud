# kube-controller-manager: The Engine Behind Declarative Kubernetes

The API server stores your desired state, but nothing enforces it yet. In this lesson, you'll install `kube-controller-manager`, the component that turns Kubernetes from a data store into a self-healing system.

---

## 📋 Objectives

- Understand how controllers use reconciliation loops to maintain desired state
- Learn which controllers `kube-controller-manager` bundles and what they do
- Install and configure `kube-controller-manager` from scratch
- Observe controllers in action: ReplicaSets, self-healing, and Deployments

By the end of this lesson, you'll understand how `kube-controller-manager` turns the Kubernetes API from a simple data store into a self-healing, declarative system.

---

> **Important** 🐛 Reporting issues  
> If you encounter any issues throughout the course, please report them here.

---

## 🧠 From Static Storage to Active Enforcement

So far in this course, you've worked with Pods and Nodes directly. The API server stores them, the scheduler assigns Pods to Nodes, and the kubelet runs them. That's a working system, but a fragile one.

What happens when a Pod crashes? Who creates a replacement? What happens when you want three copies of a service running at all times? Who watches and reacts?

The answer is **controllers**.

---

## 🔄 Control Loops and Reconciliation

A **controller** is a program that continuously watches the state of the cluster and takes action to move the current state closer to the desired state.

This is called a **reconciliation loop**, and it follows a simple pattern:

1. **Observe** the current state of resources (via the API server)
2. **Compare** current state with the desired state
3. **Act** to close the gap (create, update, or delete resources)
4. **Repeat**

![alt text](image-10.png)

Think of it like a thermostat. You set the desired temperature (desired state), the thermostat reads the room temperature (current state), and turns the heating on or off to reconcile the difference. A Kubernetes controller works the same way, just with Pods, Nodes, and other resources instead of temperatures.

> **Note** 💡 You've already seen this pattern in action. In the kubelet lesson, you learned that kubelet runs a reconciliation loop: it watches for Pod specifications, compares desired vs. actual state, and takes action.  
> kubelet is essentially a controller for a single node. `kube-controller-manager` generalizes this idea to the entire cluster.

---

## 🎯 Desired State vs. Actual State

This is the core philosophy of Kubernetes: you declare what you want (the desired state), and controllers continuously work to make it real (the actual state).

- The desired state lives in a resource's `.spec` field
- The actual state is reflected in the `.status` field
- Controllers watch for differences and act to close the gap

For example, a ReplicaSet's `.spec.replicas` says "I want 3 Pods." The ReplicaSet controller counts the actual Pods matching the selector. If there are only 2, it creates one more. If there are 4, it deletes one.

This is fundamentally different from imperative systems where you tell the system *what to do*. In Kubernetes, you tell the system *what you want*, and controllers figure out how to get there.

---

## 🏗️ What is kube-controller-manager?

`kube-controller-manager` is a control plane daemon that bundles the core controllers shipped with Kubernetes into a single binary.

Each controller is logically a separate process, but they are all compiled together and run as concurrent loops within one program. This is purely an operational convenience: running dozens of separate controller binaries would be a deployment nightmare.

Every controller communicates with the cluster exclusively through the API server. Controllers never access etcd directly. They watch for changes, make decisions, and write the results back through the API, the same way you interact with the cluster using `kubectl`.

![alt text](image-11.png)

---

## 📦 The Controllers Inside

`kube-controller-manager` ships with dozens of controllers. Here are the most important ones, grouped by what they manage:

### Workload controllers (the ones you'll interact with most often)

| Controller | What it does |
|------------|--------------|
| ReplicaSet | Ensures the desired number of Pod replicas are running at all times |
| Deployment | Manages ReplicaSets, handles rolling updates and rollbacks |
| DaemonSet | Ensures a copy of a Pod runs on every (or selected) Node(s) |
| StatefulSet | Manages stateful workloads with stable identity and ordered operations |
| Job / CronJob | Runs tasks to completion (once or on a schedule) |

### Infrastructure controllers (these run quietly in the background)

| Controller | What it does |
|------------|--------------|
| ServiceAccount | Auto-creates a default service account in every new namespace |
| Namespace | Cleans up all resources when a namespace is deleted |
| Node Lifecycle | Detects unreachable nodes and evicts their Pods |
| Garbage Collector | Deletes orphaned resources (e.g., Pods whose ReplicaSet was deleted) |

There are even more controllers in `kube-controller-manager` beyond these.

> **Note** 💡 You can see the full list of controllers and selectively enable or disable them using the `--controllers` flag when starting `kube-controller-manager`.

---

## ☁️ Core vs. Cloud vs. Custom Controllers

Not all controllers live inside `kube-controller-manager`.

- **`kube-controller-manager`** contains the **core controllers**: those that are cloud-agnostic and handle fundamental Kubernetes resources. Everything listed above (and more) falls into this category.
- **`cloud-controller-manager`** is a separate binary that contains cloud-provider-specific controllers. It handles things like:
  - Creating cloud load balancers for Services of type `LoadBalancer`
  - Updating Node objects with cloud metadata (instance type, region)
  - Configuring cloud network routes for pod networking

The split exists because cloud providers release at a different pace than Kubernetes itself. Separating cloud logic into its own binary lets providers develop and ship independently.

Historically, all cloud-specific logic lived inside `kube-controller-manager`. Each cloud provider maintained their code in the main Kubernetes repository. This monolithic approach created tight coupling and slow release cycles.

The `cloud-controller-manager` was introduced to decouple cloud-specific functionality, allowing providers to maintain their own out-of-tree implementations.

This is why you won't find any AWS, GCP, or Azure-specific code in `kube-controller-manager` today.

- **Custom controllers** (often called Operators) are controllers you write and deploy yourself. They follow the exact same reconciliation pattern but typically watch Custom Resources (CRDs) instead of built-in types.

Popular examples include:
- cert-manager
- Prometheus Operator
- ArgoCD

---

## 🧪 Without Controllers: A Gap in the System

Before installing `kube-controller-manager`, let's see what happens when no controllers are running.

Right now, the cluster has an API server and a scheduler, but no controller manager. The API server happily stores any resource you create, but nobody is watching and reacting to them.

Create a ReplicaSet that requests 3 replicas:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: podinfo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      automountServiceAccountToken: false
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:latest
EOF
```

📌 *Start playground to activate this check*

Check the ReplicaSet:

```bash
kubectl get replicaset podinfo
```

The ReplicaSet object exists in the API server. Now check if any Pods were created:

```bash
kubectl get pods -l app=podinfo
```

You should see `No resources found in default namespace`.

**No Pods.** The API server stored the ReplicaSet, but nobody is running the reconciliation loop that would notice "desired replicas = 3, actual Pods = 0" and create the missing Pods.

This is the gap that `kube-controller-manager` fills. Without it, the API server is just a database: it stores your desired state but does nothing to make it real.

---

## 📦 Installing kube-controller-manager

Download and install `kube-controller-manager`:

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-controller-manager"

sudo install -m 755 kube-controller-manager /usr/local/bin
```

📌 *Start playground to activate this check*

Download the systemd unit file for `kube-controller-manager`:

```bash
sudo wget -O /etc/systemd/system/kube-controller-manager.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/04-kube-controller-manager/__static__/kube-controller-manager.service?v=1777378796
```

📌 *Start playground to activate this check*

---

## ⚙️ Configuration Flags

Like other control plane components, `kube-controller-manager` is configured via flags. You'll encounter many of these flags as the course progresses. For now, take a look at the systemd unit file:

```bash
cat /etc/systemd/system/kube-controller-manager.service
```

| Flag | Purpose |
|------|---------|
| `--allocate-node-cidrs=true` | Assigns Pod CIDR ranges to each Node |
| `--client-ca-file` | CA certificate for verifying client certificates on the secure serving endpoint |
| `--cluster-cidr` | The CIDR range for Pod IPs across the cluster |
| `--cluster-name` | Name of the cluster (used in some cloud-related contexts) |
| `--cluster-signing-cert-file` | CA certificate used to sign CertificateSigningRequests |
| `--cluster-signing-key-file` | CA private key used to sign CertificateSigningRequests |
| `--controllers` | Which controllers to enable (`*` means all, plus explicitly named extras) |
| `--kubeconfig` | Path to kubeconfig for API server communication |
| `--root-ca-file` | Root CA that gets injected into every namespace's default ServiceAccount |
| `--service-account-private-key-file` | Private key for signing ServiceAccount tokens |
| `--service-cluster-ip-range` | The CIDR range for Service ClusterIPs (must match kube-apiserver) |
| `--use-service-account-credentials=true` | Each controller authenticates with its own service account |

---

## 🔑 Configuring Authentication for kube-controller-manager

Before you can start the `kube-controller-manager` service, you need to configure authentication, so it can communicate with the `kube-apiserver`.

> **Note** 💡 Configuring authentication was covered in a previous lesson.  
> The steps are exactly the same as configuring `kubectl`.

Generate a certificate and key for `kube-controller-manager`:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out controller-manager.key 2048
sudo openssl req -new -key controller-manager.key -out controller-manager.csr -subj "/CN=system:kube-controller-manager"
sudo openssl x509 -req -in controller-manager.csr -out controller-manager.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

Create a kubeconfig file for `kube-controller-manager`. The first command creates `/etc/kubernetes/controller-manager.conf` if it doesn't exist; the next commands add credentials and select the default context:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --client-certificate=/etc/kubernetes/pki/controller-manager.crt \
    --client-key=/etc/kubernetes/pki/controller-manager.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/controller-manager.conf
```

📌 *Start playground to activate this check*

Reload the systemd daemon and start the `kube-controller-manager` service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kube-controller-manager
sudo systemctl status kube-controller-manager --no-pager
```

---

## 🚀 Watching Controllers in Action

With `kube-controller-manager` running, the cluster's controllers are now active. Remember the ReplicaSet you created earlier with 3 replicas and zero Pods?

Check the Pods again (it may take a few seconds for the controller to reconcile):

```bash
kubectl get pods -l app=podinfo
```

📌 *Start playground to activate this check*

The ReplicaSet controller detected the existing ReplicaSet, saw that 0 out of 3 desired Pods existed, and immediately created the missing ones.

This is **reconciliation in action**: the controller didn't need a special signal or event to know something was wrong. It simply compared desired state (3 replicas) with actual state (0 Pods) and acted.

---

## 💪 Self-Healing

One of the most useful properties of reconciliation loops is **self-healing**. If something disrupts the current state, the controller automatically corrects it.

Delete one of the Pods:

```bash
POD_NAME=$(kubectl get pods -l app=podinfo -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME
```

Now check the Pods again (give it a moment, the controller needs to notice the change and react):

```bash
kubectl get pods -l app=podinfo
```

The ReplicaSet controller noticed one Pod was missing and created a replacement. The system healed itself without any manual intervention.

---

## 🔗 Cascading Controllers

Controllers don't just manage Pods, they manage each other.

Create a Deployment:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      automountServiceAccountToken: false
      containers:
        - name: nginx
          image: nginx:latest
EOF
```

📌 *Start playground to activate this check*

Check what happened:

```bash
kubectl get deployment nginx
kubectl get replicasets -l app=nginx
kubectl get pods -l app=nginx
```

Here's what happened behind the scenes:

1. You created a Deployment (desired state: 2 replicas of nginx)
2. The Deployment controller saw the new Deployment and created a ReplicaSet
3. The ReplicaSet controller saw the new ReplicaSet and created 2 Pods

Three independent control loops, each watching their own resource type, composing together to turn a single Deployment manifest into running containers. No central orchestrator needed, just controllers reacting to state changes.

---

## 📚 Lesson Recap

In this lesson, you learned about `kube-controller-manager`, the component that runs the core control loops responsible for maintaining the desired state of a Kubernetes cluster.

### Key Takeaways

- **Reconciliation loops**: Each controller continuously observes, compares, and acts to close the gap between desired and actual state, the fundamental mechanism that makes Kubernetes declarative and self-healing
- **Bundled controllers**: `kube-controller-manager` packages dozens of controllers (ReplicaSet, Deployment, Job, Namespace, ServiceAccount, Node Lifecycle, and many more) into a single binary for operational simplicity
- **Self-healing**: When the actual state drifts from the desired state (a Pod crashes, a Node goes down), controllers automatically correct the difference without manual intervention
- **Cascading composition**: Controllers compose together: a Deployment creates a ReplicaSet, which creates Pods, which get scheduled, each controller handling its own concern independently
- **Extensibility**: Beyond the core controllers, Kubernetes supports `cloud-controller-manager` for cloud-specific logic and custom controllers (operators) for user-defined resources

With `kube-controller-manager` running alongside the API server and scheduler, your control plane can now manage workloads declaratively. Resources like Deployments, ReplicaSets, Jobs, and DaemonSets are no longer just stored objects: they are actively reconciled into running reality.

---

> **Important**  
> The controller pattern and reconciliation model go much deeper than what's covered here. Check out the references for a closer look at the controller architecture and how to write your own.

---

## 📖 Additional Resources

- https://kubernetes.io/docs/concepts/architecture/controller/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
- https://kubernetes.io/docs/concepts/architecture/cloud-controller/
- https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/concepts/architecture/garbage-collection/
- https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
- https://kubespec.dev/kubernetes/v1/Pod
- https://kubespec.dev/kubernetes/apps/v1/ReplicaSet
- https://kubespec.dev/kubernetes/apps/v1/Deployment