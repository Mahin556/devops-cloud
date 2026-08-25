# kube-scheduler: Automating Pod Placement Across Nodes

Pods can be stored in the API server, but nobody assigns them to nodes yet. In this lesson, you'll install `kube-scheduler` and watch it automatically place Pods on the most suitable nodes.

---

## 📋 Objectives

- Understand `kube-scheduler`'s role within a Kubernetes cluster
- Explore how Pods are assigned to Nodes (manually and via Binding)
- Install and configure `kube-scheduler` from scratch
- Observe automated Pod scheduling in action

By the end of this lesson, you'll have automatic Pod scheduling working: create a Pod and watch it land on a node.

---

## 🤔 What's the Difference Between Kubernetes and Docker?

This is one of the most common questions asked by newcomers to Kubernetes.

Kubernetes is a container orchestration platform that manages the deployment, scaling, and operation of containerized applications across a cluster of machines.

This multi-machine capability (among other things) is what sets Kubernetes apart from single-host container runtimes like Docker. Kubernetes can distribute workloads across multiple nodes, ensuring applications are deployed and scaled efficiently and reliably.

However, Kubernetes cannot randomly decide where to place workloads. It needs to make informed decisions, otherwise its actions could lead to resource contention, performance degradation, or application failure.

---

## 🧠 Understanding Scheduling

In Kubernetes, **scheduling** refers to making sure that Pods are matched to Nodes so that the kubelet can run them.

A scheduler watches for newly created Pods that have no assigned Node. For every unscheduled Pod, the scheduler becomes responsible for finding the best node for that Pod to run on.

> **Note** 💡 How the best node is determined depends on what factors the scheduler considers.  
> Typically, the scheduler considers factors such as resource availability, node affinity, pod priorities, and more to make optimal scheduling decisions.

`kube-scheduler` is the default scheduler for Kubernetes and runs as part of the control plane.

> **Note** 💡 Notice that `kube-scheduler` is the default scheduler.  
> Kubernetes allows users to implement their own schedulers if they want to customize the scheduling process.

![alt text](image-9.png)

---

## 🧪 Manual Pod Assignment (Without a Scheduler)

Before installing `kube-scheduler`, let's explore how Kubernetes assigns Pods to Nodes.

### Create a Pod Without a Scheduler

Create a new Pod to see what happens when there is no scheduler:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-unscheduled
spec:
  automountServiceAccountToken: false
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
EOF
```

📌 *Start playground to activate this check*

At this point, the Pod exists but remains unscheduled (it has no assigned Node):

```bash
kubectl get pod podinfo-unscheduled -o jsonpath='{.spec.nodeName}'
```

Since there is no scheduler installed, this isn't going to change: the Pod will remain unscheduled.

---

### Creating a Fake Node

It is possible to assign a Pod to a specific Node by setting the `nodeName` field directly in the Pod specification, essentially bypassing the scheduler.

But in order to do so, you need an existing Node in the cluster.

Create a (fake) Node object that will serve as the scheduling target:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Node
metadata:
  name: worker-1
status:
  capacity:
    cpu: "4"
    memory: 8Gi
    pods: "110"
  allocatable:
    cpu: "4"
    memory: 8Gi
    pods: "110"
  conditions:
    - type: Ready
      status: "True"
      reason: KubeletReady
      message: Node is ready
EOF
```

> **Note** 💡 This is yet another proof that the kube-apiserver is a plain old REST API server: it doesn't care whether a real machine backs the Node object, it just stores the data.

Create a new Pod and assign it to the Node:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-node-name
spec:
  nodeName: worker-1
  automountServiceAccountToken: false
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
EOF
```

Verify that the Pod was assigned to the selected Node:

```bash
kubectl get pod podinfo-node-name -o jsonpath='{.spec.nodeName}'
```

📌 *Start playground to activate this check*

While this approach works when you need to place a Pod on a specific node, manually assigning Pods to Nodes isn't scalable, may not be possible in all scenarios, and largely defeats the purpose of container orchestration.

---

## 🔗 The Binding Mechanism

However, there's a more fundamental problem with regards to scheduling: Pods are (mostly) immutable objects. Once created, a Pod's specification cannot be modified, including the `nodeName` field.

This immutability raises an important question: if a Pod is created without a `nodeName` (unscheduled) and Pods cannot be modified after creation, how does a scheduler assign it to a Node?

The answer lies in a special Kubernetes resource called **Binding**. It is an internal Pod subresource that provides a dedicated API path for assigning Pods to Nodes. Instead of requiring a full Pod update, it allows a targeted operation on the Pod's `/binding` subresource, which sets the Pod's `spec.nodeName` field.

Since `kubectl` doesn't support Binding creation directly (it's an internal operation), use the Kubernetes API directly to create a Binding object for the previously created Pod:

```bash
curl -f -k https://127.0.0.1:6443/api/v1/namespaces/default/pods/podinfo-unscheduled/binding \
    --cacert /etc/kubernetes/pki/ca.crt \
    --cert /etc/kubernetes/pki/admin.crt \
    --key /etc/kubernetes/pki/admin.key \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{
      "apiVersion": "v1",
      "kind": "Binding",
      "metadata": {
        "name": "podinfo-unscheduled"
      },
      "target": {
        "apiVersion": "v1",
        "kind": "Node",
        "name": "worker-1"
      }
    }'
```

> **Note** 💡 Reminder: the API server uses TLS for secure communication AND authentication (as explained in the previous lesson).

Verify that the Binding successfully assigned the Pod to the Node:

```bash
kubectl get pod podinfo-unscheduled -o jsonpath='{.spec.nodeName}'
```

📌 *Start playground to activate this check*

Check the status of both Pods to see the final result:

```bash
kubectl get pods -o wide
```

> **Note** 💡 Even though Pods are assigned, since there is no real node (kubelet) behind the Node object, the Pods remain in `Pending` state.

---

## 📦 Installing kube-scheduler

Download and install `kube-scheduler`:

```bash
KUBE_VERSION=v1.34.0

curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-scheduler"

sudo install -m 755 kube-scheduler /usr/local/bin
```

📌 *Start playground to activate this check*

Download the systemd unit file for `kube-scheduler`:

```bash
sudo wget -O /etc/systemd/system/kube-scheduler.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/03-kube-scheduler/__static__/kube-scheduler.service?v=1777378795
```

📌 *Start playground to activate this check*

---

## 🔑 Configuring Authentication for kube-scheduler

Before you can start the `kube-scheduler` service, you need to configure authentication, so it can communicate with the `kube-apiserver`.

> **Note** 💡 Configuring authentication was covered in the previous lesson.  
> The steps are exactly the same as configuring `kubectl`.

Generate a certificate and key for `kube-scheduler`:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out scheduler.key 2048
sudo openssl req -new -key scheduler.key -out scheduler.csr -subj "/CN=system:kube-scheduler"
sudo openssl x509 -req -in scheduler.csr -out scheduler.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

Create a kubeconfig file for `kube-scheduler`. The first command creates `/etc/kubernetes/scheduler.conf` if it doesn't exist; the next commands add credentials and select the default context:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --client-certificate=/etc/kubernetes/pki/scheduler.crt \
    --client-key=/etc/kubernetes/pki/scheduler.key \
    --embed-certs=true

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/scheduler.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/scheduler.conf
```

📌 *Start playground to activate this check*

Reload the systemd daemon and start the `kube-scheduler` service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now kube-scheduler
```

---

## 🚀 Testing Automated Scheduling

With `kube-scheduler` installed, Pods can now be scheduled automatically onto Nodes in the cluster. Behind the scenes, `kube-scheduler` detects unscheduled Pods, evaluates available Nodes, and creates a Binding to assign each Pod to the best candidate.

Before testing, there's one thing to take care of. The fake Node you created earlier automatically got a `node.kubernetes.io/not-ready` taint because no real kubelet is reporting in.

The scheduler won't place Pods on tainted Nodes, so remove the taint first:

```bash
kubectl taint node worker-1 node.kubernetes.io/not-ready-
```

Create a new Pod to test scheduling:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: podinfo-scheduler
spec:
  automountServiceAccountToken: false
  containers:
    - name: podinfo
      image: ghcr.io/stefanprodan/podinfo:latest
EOF
```

Verify that the Pod was assigned to a Node:

```bash
kubectl get pod podinfo-scheduler -o jsonpath='{.spec.nodeName}'
```

---

## 📚 Lesson Recap

In this lesson, you learned about `kube-scheduler`, the default scheduler component that assigns Pods to Nodes in a Kubernetes cluster.

### Key Takeaways

- **Pod placement**: `kube-scheduler` watches for newly created Pods without assigned Nodes and makes informed decisions about optimal Node placement based on resource availability, node affinity, pod priorities, and other factors
- **Binding mechanism**: Since Pods are mostly immutable, `kube-scheduler` uses the internal Binding subresource to set a Pod's `spec.nodeName` field through a dedicated API path, rather than requiring a full Pod update
- **Extensible design**: As the default scheduler, `kube-scheduler` can be replaced with custom schedulers when specialized scheduling logic is required

With `kube-scheduler` now running alongside `kube-apiserver`, you have established the core scheduling capability that enables Kubernetes to automatically distribute workloads across your cluster nodes.

---

> **Important**  
> Kubernetes scheduling is much more involved than what's covered here. Check out the references for a deeper look at the scheduling framework.

---

## 📖 Additional Resources

- https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/binding-v1/
- https://kubernetes.io/docs/reference/scheduling/config/
- https://kubernetes.io/docs/tasks/extend-kubernetes/configure-multiple-schedulers/
- https://kubespec.dev/kubernetes/v1/Pod
