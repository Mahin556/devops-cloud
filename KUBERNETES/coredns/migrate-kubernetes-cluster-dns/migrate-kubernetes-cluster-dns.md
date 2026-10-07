# Changing a cluster DNS suffix

```text
cluster.local
```
to:
```text
iximiuz.cluster
```

### The 3 things you must change

```text
                    Kubernetes DNS domain
                           │
             ┌─────────────┼─────────────┐
             ↓             ↓             ↓
          CoreDNS        kubelet      kubeadm-config
          ConfigMap      config.yaml     ConfigMap
             │             │             │
             ↓             ↓             ↓
      DNS server knows   Pods get      Future nodes
      iximiuz.cluster    correct       get correct
                         search domain  configuration
```

Missing any one of them will either break DNS resolution immediately or cause failures when new nodes join the cluster in the future.

---

### Change CoreDNS

Every `cluster.local` reference inside the Corefile must be changed to iximiuz.cluster: the zone argument on the kubernetes plugin line, and the two disable lines inside the cache block. After editing, restart CoreDNS to apply the change.

CoreDNS reads its configuration from the `coredns` ConfigMap in `kube-system`.

First inspect it:

```bash
kubectl edit configmap coredns -n kube-system
```

Inside the `Corefile`, you'll likely have:

```text
kubernetes cluster.local in-addr.arpa ip6.arpa {

cache 30 {
    disable success cluster.local
    disable denial cluster.local
}
```

Change **all three occurrences**:

```text
kubernetes iximiuz.cluster in-addr.arpa ip6.arpa {

cache 30 {
    disable success iximiuz.cluster
    disable denial iximiuz.cluster
}
```

**Why?**

This tells CoreDNS:

> "I am authoritative for Kubernetes services under `iximiuz.cluster`."

So instead of:
```text
nginx.domain.svc.cluster.local
```

CoreDNS will answer:
```text
nginx.domain.svc.iximiuz.cluster
```

**Restart CoreDNS**

After changing its ConfigMap:
```bash
kubectl rollout restart deployment/coredns -n kube-system
```

Then:
```bash
kubectl rollout status deployment/coredns -n kube-system
```

You can check the CoreDNS Pods:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

### Change kubelet on BOTH nodes

kubelet is the node agent on every node. kubelet's `clusterDomain` setting tells it what DNS suffix to append when resolving service names. This must be updated on both `cplane-01` and `node-01`. After editing, restart kubelet on each node.

kubelet reads its configuration from `/var/lib/kubelet/config.yaml`.

On `cplane-01`:
```bash
sudo vi /var/lib/kubelet/config.yaml
```

Find:
```yaml
clusterDomain: cluster.local
```

Change:
```yaml
clusterDomain: iximiuz.cluster
```

Then:
```bash
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

Do the **same thing on `node-01`**.

You can verify:
```bash
kubectl get nodes
```

Both should remain:
```text
NAME        STATUS   ROLES
cplane-01   Ready    control-plane
node-01     Ready    <none>
```

**Why does kubelet need changing?**

This is slightly different from CoreDNS.
Kubelet creates `/etc/resolv.conf` inside Pods.

Before:
```text
search domain.svc.cluster.local svc.cluster.local cluster.local
```

After:
```text
search domain.svc.iximiuz.cluster svc.iximiuz.cluster iximiuz.cluster
```

So kubelet tells the Pod:

> "When you're trying to resolve short Kubernetes names, use `iximiuz.cluster`."

---

### Restart the existing nginx Pods

After updating kubelet on both nodes, restart the nginx Deployment in the domain namespace. Existing pods were created with `cluster.local` in their `/etc/resolv.conf` and must be recreated to get `iximiuz.cluster` injected by kubelet.

Changing kubelet doesn't magically modify `/etc/resolv.conf` inside Pods that already exist.

So restart the Deployment:
```bash
kubectl rollout restart deployment nginx -n domain
```

Then:
```bash
kubectl rollout status deployment nginx -n domain
```

Check the new Pod:
```bash
POD=$(kubectl get pod -n domain -l app=nginx -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$POD" -n domain -- cat /etc/resolv.conf
```

You should see something similar to:
```text
nameserver 10.96.0.10
search domain.svc.iximiuz.cluster svc.iximiuz.cluster iximiuz.cluster
options ndots:5
```

Notice:
```text
iximiuz.cluster
```

---

### Update kubeadm-config

This one is easy to overlook.

kubeadm-config is the ConfigMap that kubeadm reads to configure kubelet on a node when it joins the cluster via `kubeadm join`.

If `dnsDomain` is not updated here, any future node will join with `cluster.local` instead of `iximiuz.cluster`, causing DNS failures for all pods on that node. Update the cluster configuration to reflect the new DNS domain and ensure consistent DNS settings across all nodes.

Run:
```bash
kubectl edit configmap kubeadm-config -n kube-system
```

Find:
```yaml
networking:
  dnsDomain: cluster.local
```

Change to:
```yaml
networking:
  dnsDomain: iximiuz.cluster
```

### Why?

This doesn't primarily fix your **current** Pods.

It's for **future nodes**.

Think of it like this:

```text
Current nodes
     │
     ├── kubelet config.yaml
     │
     └── already configured


Future node
     │
     ↓
kubeadm join
     │
     ↓
kubeadm-config
     │
     ↓
dnsDomain: iximiuz.cluster
     │
     ↓
new node gets correct kubelet configuration
```

If you don't update it, a future node could still receive:

```yaml
clusterDomain: cluster.local
```

while the rest of your cluster uses:

```text
iximiuz.cluster
```

---

### Final DNS test

Run:
```bash
kubectl run curl-test \
  --rm -it \
  --image=curlimages/curl:8.7.1 \
  --restart=Never \
  -n default -- \
  curl http://nginx.domain.svc.iximiuz.cluster
```

If everything is correct, you should get the nginx response.

