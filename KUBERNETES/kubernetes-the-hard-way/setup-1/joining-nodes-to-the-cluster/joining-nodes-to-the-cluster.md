# Connecting a Worker Node to the Control Plane

In this lesson, you'll connect the worker node and control plane you built in previous lessons into a functioning Kubernetes cluster.

> **Note** 🔜 Functioning means the cluster can run workloads. Missing pieces (like networking) will be covered in later lessons.

---

## 📋 Objectives

- Understand what it means for a node to "join" a Kubernetes cluster
- Configure the control plane to accept and authenticate worker nodes
- Use TLS bootstrapping to securely register a worker node
- Observe the node registration process and certificate approval
- Deploy a workload and watch it run on the worker node

By the end of this lesson, you'll have a Kubernetes cluster where the control plane and worker node communicate securely over TLS and can run workloads.

---

## 🔍 The Current State

Up to this point, the worker node and the control plane have been running in complete isolation:

| Side | Components | Current state |
|------|------------|---------------|
| Worker node | containerd, kubelet | Managing static Pods locally |
| Control plane | etcd, kube-apiserver, kube-scheduler, kube-controller-manager | Running, but no real nodes to schedule workloads onto |

It's time to connect them.

---

## 🤔 What Does "Joining" Mean?

When a worker node "joins" a Kubernetes cluster, three things need to happen:

1. The kubelet connects to the API server and registers itself as a Node object
2. The API server authenticates the kubelet and allows it to create and update its Node resource
3. The kubelet starts its reconciliation loop, watching for Pods assigned to it and reporting status back

Once joined, the kubelet acts as the bridge you learned about in the kubelet lesson: it watches for Pod specifications, manages containers through the CRI, and reports back to the API server.

The difference is that in addition to managing static Pods locally, it now receives work from the control plane and reports back through the API.

---

## 🔐 The Trust Problem

There's a fundamental challenge here: how does the API server trust a new kubelet?

In previous lessons, you configured control plane components (`kube-scheduler`, `kube-controller-manager`) to authenticate using client certificates signed by the cluster's CA. You generated the certificates manually and placed them on the same machine.

For worker nodes, this approach doesn't scale well. In a real cluster, you might have hundreds of nodes, and manually generating and distributing certificates for each one is impractical.

Kubernetes solves this with **TLS bootstrapping**: a process that allows a kubelet to use a temporary, low-privilege token to request a proper client certificate from the API server. Once the certificate is approved and issued, the kubelet switches to using it for all future communication.

![alt text](image-12.png)

---

## 🖥️ Configuring the Control Plane

> **⚠️ Run the commands in this section on the control-plane machine.**

Before a worker node can join the cluster, the control plane needs a few things configured:

- A client certificate so `kube-apiserver` can talk back to kubelets
- Bootstrap token authentication so new kubelets can authenticate with a temporary token
- RBAC rules so bootstrap tokens have permission to request certificates

### kube-apiserver to kubelet Communication

In previous lessons, kubelet communicated only locally: it ran static Pods and exposed an API only accessed locally using `kubeletctl`. When kubelet joins a cluster, the API server needs to talk to it as well, for operations like `kubectl logs` and `kubectl exec`.

This means `kube-apiserver` needs a client certificate to authenticate itself when connecting to kubelets (otherwise they would communicate over an insecure channel).

> **Note** 💡 In the kubelet lesson you configured kubelet without TLS or authentication.  
> You will do that in the following section when configuring kubelet for joining the cluster.

Generate the certificate:

```bash
(
cd /etc/kubernetes/pki

sudo openssl genrsa -out apiserver-kubelet-client.key 2048
sudo openssl req -new -key apiserver-kubelet-client.key -out apiserver-kubelet-client.csr -subj "/CN=kube-apiserver-kubelet-client/O=system:masters"
sudo openssl x509 -req -in apiserver-kubelet-client.csr -out apiserver-kubelet-client.crt \
  -CA ca.crt -CAkey ca.key \
  -days 365
)
```

📌 *Start playground to activate this check*

### Updating kube-apiserver Config

Configure `kube-apiserver` to use the kubelet client certificate and enable bootstrap token authentication:

**/etc/systemd/system/kube-apiserver.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kube-apiserver \
    --service-cluster-ip-range=10.96.0.0/12 \
    --service-account-issuer=https://kubernetes.default.svc.cluster.local \
    --service-account-key-file=/etc/kubernetes/pki/sa.pub \
    --service-account-signing-key-file=/etc/kubernetes/pki/sa.key \
    --etcd-cafile=/etc/etcd/pki/ca.crt \
    --etcd-certfile=/etc/etcd/pki/client.crt \
    --etcd-keyfile=/etc/etcd/pki/client.key \
    --etcd-servers=https://127.0.0.1:2379 \
    --anonymous-auth=false \
    --token-auth-file=/etc/kubernetes/tokens.csv \
    --authorization-mode=Node,RBAC \
    --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
    --tls-private-key-file=/etc/kubernetes/pki/apiserver.key \
    --client-ca-file=/etc/kubernetes/pki/ca.crt \
    --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt \
    --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key \
    --enable-bootstrap-token-auth=true

# ...
```

```bash
sudoedit /etc/systemd/system/kube-apiserver.service
```

> **Note** 💡 Don't forget to add a trailing backslash `\` to the current last `ExecStart` flag before appending the new `kube-apiserver` flags.

**Flag** | **Purpose**
---|---
`--kubelet-client-certificate` | Client certificate for API server to kubelet communication
`--kubelet-client-key` | Corresponding private key
`--enable-bootstrap-token-auth` | Enables authentication using bootstrap tokens

Restart `kube-apiserver` to apply the changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kube-apiserver
```

📌 *Start playground to activate this check*

Verify the API server is still running:

```bash
kubectl cluster-info
```

---

### Bootstrap Tokens

When a new kubelet joins the cluster, it doesn't have a certificate yet. It needs some way to authenticate with the API server to request one.

Kubernetes solves this with **bootstrap tokens**: short-lived, low-privilege tokens specifically designed for the initial node registration process.

> **Note** 💡 You can bootstrap kubelet with other authentication methods too, including the regular static tokens from the kube-apiserver lesson.  
> Bootstrap tokens are preferred because they are short-lived and scoped for this join flow.

A bootstrap token has a specific format `[token-id].[token-secret]` (for example, `abcdef.0123456789abcdef`). It is stored as a `Secret` in the `kube-system` namespace with a specific type and naming convention to make it easier for the kube-apiserver to keep track of it.

> **Note** 💡 The `token-id` and `token-secret` fields together form the token `abcdef.0123456789abcdef`.

The kubelet on the worker node will use this token to authenticate during the bootstrap process.

Create the bootstrap token:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-abcdef
  namespace: kube-system

# Special type for bootstrap tokens
type: bootstrap.kubernetes.io/token

stringData:
  token-id: abcdef
  token-secret: 0123456789abcdef

  usage-bootstrap-authentication: "true"

  # Optional expiration
  # expiration: 9999-12-31T23:59:59Z

  # Optional description
  description: "Bootstrap token for kubelets to authenticate to the API server"
EOF
```

📌 *Start playground to activate this check*

> **Important** ⚠️ In production, bootstrap tokens should be short-lived, rotated regularly and unique to each kubelet.  
> Tools like `kubeadm` generate unique tokens with automatic expiration for each join operation.

---

### RBAC for Bootstrap Tokens

The bootstrap token authenticates the kubelet as a member of the `system:bootstrappers` group. By default, this group has no permissions to do anything, so you need to grant it the necessary permissions.

First and foremost, it needs access to initiate the TLS bootstrap process:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubelet-bootstrap
subjects:
  - kind: Group
    name: system:bootstrappers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:node-bootstrapper
  apiGroup: rbac.authorization.k8s.io
EOF
```

The TLS bootstrap process starts by creating a certificate signing request (CSR) for kubelet's client certificate. A CSR in this case isn't simply a regular certificate signing request, but a `CertificateSigningRequest` resource created using the Kubernetes API.

Kubernetes has a built-in mechanism for certificate signing that exists exactly for this purpose: provide a way for clients (not just kubelets) to request and obtain signed certificates from the cluster that they can use to authenticate with the API server.

Requesting a certificate isn't enough though, it needs to be approved. You can do it manually using the `kubectl certificate approve` command, but approving every single CSR manually is tedious and error-prone.

> **Note** 💡 Consider a cluster that has automatic scaling enabled. With manual approval, you'd need to approve each new node's CSR individually which is simply not scalable.

Instead, you can configure automatic approval using a CertificateSigningRequest controller (via the `kube-controller-manager`).

Naturally, approving CSRs also requires permission:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-autoapprove-bootstrap
subjects:
  - kind: Group
    name: system:bootstrappers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
  apiGroup: rbac.authorization.k8s.io
EOF
```

After the certificate is signed and received by kubelet, it switches to using the new certificate for authentication. It registers itself as a Node with the API server using the new certificate.

At this point, the bootstrap process is complete. The bootstrap token is no longer needed and can be deleted (or garbage collected once expired by the `kube-controller-manager`).

You could stop here and everything would work fine, right up until it doesn't. Certificates have an inherent security feature: they expire.

To keep nodes authenticating after their certificates expire, you need automatic certificate rotation as well. Up until this point, kubelet authenticated as an identity in the `system:bootstrappers` group. After bootstrapping completes, it switches to using a proper client certificate. The certificate issued during bootstrapping identifies kubelet as `system:node:<nodename>`, making it a member of the `system:nodes` group.

Kubernetes uses explicit RBAC permissions, so it won't automatically grant nodes the ability to rotate their own certificates.

You need to grant that permission explicitly:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-autoapprove-certificate-rotation
subjects:
  - kind: Group
    name: system:nodes
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
  apiGroup: rbac.authorization.k8s.io
EOF
```

📌 *Start playground to activate this check*

#### Summary of ClusterRoleBindings

| ClusterRoleBinding | ClusterRole | Group | Purpose |
|--------------------|-------------|-------|---------|
| `kubelet-bootstrap` | `system:node-bootstrapper` | `system:bootstrappers` | Allows creating CSRs |
| `node-autoapprove-bootstrap` | `system:certificates.k8s.io:certificatesigningrequests:nodeclient` | `system:bootstrappers` | Auto-approves initial node CSRs |
| `node-autoapprove-certificate-rotation` | `system:certificates.k8s.io:certificatesigningrequests:selfnodeclient` | `system:nodes` | Auto-approves certificate renewals |

The first two bindings are for the initial bootstrap process. The third enables automatic certificate rotation after the node has joined.

The control plane is now ready to accept worker nodes.

---

## 🖥️ Configuring the Worker Node

> **⚠️ Run the commands in this section on the worker machine.**

With the control plane ready to accept new nodes, it's time to configure the worker.

The kubelet needs three things to join the cluster:

1. The cluster's CA certificate to verify the API server's identity
2. A bootstrap kubeconfig containing the API server address and the bootstrap token
3. An updated systemd service that uses TLS bootstrapping instead of standalone mode

### Distributing the CA Certificate

The worker needs the cluster's CA certificate to establish a trusted connection to the API server.

In the real world, you would distribute this certificate through a secure channel.

For this lab, copy the CA certificate from the control plane:

```bash
sudo mkdir -p /etc/kubernetes/pki
sudo scp control-plane:/etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.crt
```

📌 *Start playground to activate this check*

> **Note** 💡 The CA certificate is the only piece of PKI material you need to copy manually.  
> Everything else (the kubelet's client certificate and key) will be obtained automatically through the bootstrap process.

### Configuring TLS for the kubelet API

The kubelet API does NOT require any authentication at the moment. This was fine for playing with the API locally, but in a production environment, you would want to configure authentication.

> **Note** 💡 The most common authentication method for kubelet is x509 client certificates.  
> In this case, kubelet will use the cluster CA certificate to verify client certificates presented by the `kube-apiserver`.

Update the kubelet configuration to require authentication:

**/var/lib/kubelet/config.d/70-authnz.conf**

```yaml
cat << EOF > /var/lib/kubelet/config.d/70-authnz.conf
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: false
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt

authorization:
  mode: AlwaysAllow
EOF
```

📌 *Start playground to activate this check*

### Creating the Bootstrap kubeconfig

Like any other client, the bootstrap kubeconfig tells kubelet where to find the API server and how to authenticate during initial registration.

> **Note** 💡 From this perspective, the bootstrap token works just like the token authentication discussed in the kube-apiserver lesson.

Create the bootstrap kubeconfig:

```bash
sudo kubectl config set-cluster default \
    --kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=https://control-plane:6443

sudo kubectl config set-credentials default \
    --kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
    --token=abcdef.0123456789abcdef

sudo kubectl config set-context default \
    --kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
    --cluster=default \
    --user=default

sudo kubectl config use-context default \
    --kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf
```

📌 *Start playground to activate this check*

### Updating the kubelet Service

In the kubelet lesson, kubelet was configured through files.

To join a cluster, the kubelet process needs two additional flags:

- `--bootstrap-kubeconfig`: Path to the bootstrap kubeconfig for initial authentication
- `--kubeconfig`: Path where kubelet will write its permanent kubeconfig after bootstrapping

You need to add these flags to the kubelet systemd service file:

**/etc/systemd/system/kubelet.service**

```ini
[Unit]
# ...

[Service]
# ...

ExecStart=/usr/local/bin/kubelet \
    --config-dir /var/lib/kubelet/config.d/ \
    --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
    --kubeconfig=/etc/kubernetes/kubelet.conf

# ...
```

```bash
sudoedit /etc/systemd/system/kubelet.service
```

Restart kubelet to apply the changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

📌 *Start playground to activate this check*

The worker node is now ready to join the cluster.

---

## 🌐 Joining the Cluster

> **⚠️ You will go back and forth between machines in this section.**

Start on the **control-plane** machine.

After restarting kubelet in the previous section, it should automatically start the join process without any further configuration.

You can verify this by checking the node list:

```bash
kubectl wait --for=create node worker
kubectl get nodes
```

📌 *Start playground to activate this check*

### What Just Happened?

When kubelet started with `--bootstrap-kubeconfig`, it kicked off the TLS bootstrapping process:

1. kubelet connected to the API server using the bootstrap token
2. It generated a private key and submitted a CertificateSigningRequest (CSR) to the API server
3. The CSR controller (running inside `kube-controller-manager`) auto-approved the CSR based on the RBAC rules you configured
4. `kube-controller-manager` signed the certificate using the cluster CA
5. kubelet retrieved the signed certificate and saved it along with a new kubeconfig
6. kubelet switched to using the new kubeconfig and certificate for all future API server communication
7. kubelet registered itself as a Node in the cluster

![alt text](image-13.png)

You can verify the CSR that was created and approved during the bootstrap process:

```bash
kubectl get csr
```

You should see a CSR with the status `Approved,Issued`, confirming that the certificate was automatically approved and issued by the `kube-controller-manager`.

### Why the Node is NotReady

If you check the node list, you will see that the worker node is in the `NotReady` state.

```bash
kubectl get nodes
```

kubelet runs a number of checks before marking the node as Ready. The kube-scheduler sees this and waits for the node to become Ready before scheduling workloads onto it. Otherwise, workloads could be scheduled to a node that isn't ready to run them reliably, leading to all sorts of failures.

In this case, the failing check is network readiness: the node has no CNI configuration yet. That's expected, because you'll configure networking and CNI in the next lesson.

You can verify this by looking at the node status:

```bash
kubectl describe node worker
```

You should see something like this:

```
container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
```

> **Note** 💡 `kubectl describe` is one of the most underrated commands in Kubernetes.  
> When you need to debug a problem, `kubectl describe` should be one of the first commands you run.

---

## 🔌 Workaround: Minimal CNI Config

kubelet is already running, but the node won't become Ready until the runtime reports networking is configured. For this lab, we can unblock containerd by adding a minimal CNI configuration.

> **Important** ⚠️ Run the following commands on the **worker** machine.

Create the following configuration file:

**/etc/cni/net.d/99-loopback.conf**

```json
{
  "cniVersion": "1.0.0",
  "name": "lo",
  "type": "loopback"
}
```

```bash
sudo mkdir -p /etc/cni/net.d
sudoedit /etc/cni/net.d/99-loopback.conf
```

> **Important** ⚠️ Run the following commands on the **control-plane** machine.

kubelet should automatically recover once containerd reports that the network is ready.

You can verify this by running:

```bash
kubectl wait --for=condition=Ready node worker
kubectl get nodes
```

You should see the worker node in the `Ready` state.

📌 *Start playground to activate this check*

---

## 🚀 Deploying a Workload

Now that the node is Ready, workloads can actually run, not just get scheduled.

Create a ReplicaSet to verify the cluster is fully operational:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: podinfo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      hostNetwork: true
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:latest
          ports:
            - containerPort: 9898
EOF
```

📌 *Start playground to activate this check*

Wait for the ReplicaSet to create a Pod:

```bash
kubectl get replicaset podinfo
kubectl get pods -l app=podinfo -w
```

Then check the resulting Pod:

```bash
kubectl get pods -l app=podinfo -o wide
```

📌 *Start playground to activate this check*

This is the full Kubernetes lifecycle in action:

- `kubectl` sent the ReplicaSet specification to `kube-apiserver`
- `kube-apiserver` stored it in etcd
- `kube-controller-manager` saw that no Pods matched the desired replica count and created one
- `kube-scheduler` detected the unscheduled Pod and assigned it to the worker node
- `kubelet` on the worker node received the Pod specification
- `kubelet` instructed containerd to pull the image and start the container
- `kubelet` reported the Pod status back to the API server

Every component you installed across this course just worked together to run a single container.

---

## 📚 Lesson Recap

In this lesson, you connected a worker node to the control plane, forming a functioning Kubernetes cluster.

### Key Takeaways

- **TLS bootstrapping**: kubelet uses a temporary bootstrap token to authenticate with the API server, then automatically requests and receives a client certificate, eliminating the need for manual certificate distribution
- **Mutual authentication**: The API server authenticates kubelets via their certificates, and kubelets verify the API server using the cluster CA, establishing trust in both directions
- **RBAC for bootstrapping**: Three ClusterRoleBindings control the bootstrap process: one allows creating CSRs, another auto-approves initial node certificates, and the third enables automatic certificate rotation
- **Node registration**: when kubelet starts with a bootstrap kubeconfig, it registers itself as a Node object in the cluster, making it available for scheduling

With the worker node connected to the control plane, you have a real Kubernetes cluster. Pods are no longer just API objects sitting in etcd: they are running containers on actual machines.

However, the cluster still has a limitation: Pods running on the worker node can't communicate with Pods on other nodes (or even with each other through Services).

The next lessons will address this by setting up cluster networking.

---

## 📖 Additional Resources

💡 To learn more about the concepts covered in this lesson, check out the resources below.

- [TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/)
- [Bootstrap tokens](https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/)
- [Authenticating with bootstrap tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#bootstrap-tokens)
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [kubelet authentication/authorization](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/)
- [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)
- [kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/)
- [API resources](https://kubernetes.io/docs/reference/kubernetes-api/)