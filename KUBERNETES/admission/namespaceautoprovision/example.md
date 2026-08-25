Admission control is the **final gatekeeper** that validates and potentially modifies requests before they're stored in etcd.

### The Admission Control Flow

```
API Request → Authentication → Authorization → Admission Control → etcd
```

### Key Concepts Made Simple

**Admission Controllers**: Built-in plugins that run during the admission phase
**Mutating Webhooks**: Can **change** your request (like adding labels)
**Validating Webhooks**: Can **accept or reject** your request (like enforcing rules)

---

### Step 1: Check Default Admission Controllers

Let's first understand what admission controllers are enabled by default in your cluster:

```bash
# Method 1: Check API server pod configuration
kubectl get pod kube-apiserver-controlplane -n kube-system -o yaml | grep -i admission

# Method 2: Check API server process (on control plane node)
ps aux | grep kube-apiserver | grep enable-admission-plugins

# Method 3: For managed clusters, check cluster info
kubectl exec -it kube-apiserver-controlplane -n kube-system -- kube-apiserver -h | grep 'enable-admission-plugins'

```

**Expected Output**: You should see controllers like:
- `NamespaceLifecycle`
- `LimitRanger` 
- `ServiceAccount`
- `DefaultStorageClass`
- `ResourceQuota`
- `DefaultTolerationSeconds`
- `NodeRestriction`

---

## 🧪 Part 3: NamespaceAutoProvision Demonstration

### Exercise 1: Understanding NamespaceLifecycle Controller

The `NamespaceLifecycle` admission controller (enabled by default) prevents creation of resources in non-existent namespaces. Let's see this in action!

**Step 1**: Try to create a pod in a non-existent namespace

```yaml
# Create file: pod-in-missing-namespace.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: test  # This namespace doesn't exist!
spec:
  containers:
  - name: nginx
    image: nginx:1.20
```

**Step 2**: Apply and observe the error

```bash
kubectl apply -f pod-in-missing-namespace.yaml
```

**Expected Error**: 
```
Error from server (NotFound): namespaces "test" not found
```

### Exercise 2: Enabling NamespaceAutoProvision

Now let's enable the `NamespaceAutoProvision` admission controller to automatically create missing namespaces.

**Step 1**: Backup the current API server configuration

```bash
# SSH to your control plane node first
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml.backup
```

**Step 2**: Edit the API server configuration

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Find the `--enable-admission-plugins` line and add `NamespaceAutoProvision`:

```yaml
# Before (example):
- --enable-admission-plugins=NodeRestriction,ResourceQuota,LimitRanger

# After:
- --enable-admission-plugins=NodeRestriction,ResourceQuota,LimitRanger,NamespaceAutoProvision
```

**Step 3**: Wait for API server to restart (it will restart automatically)

```bash
# Watch the API server pod restart
kubectl -n kube-system get pods -w | grep kube-apiserver
```

**Step 4**: Verify the admission controller is enabled

```bash
kubectl -n kube-system get pod kube-apiserver-controlplane -o yaml | grep -i admission
```

**Step 5**: Now try creating the pod again

```bash
kubectl apply -f pod-in-missing-namespace.yaml
```

**Expected Result**: The pod should be created successfully, and the `test` namespace should be auto-created!

**Step 6**: Verify namespace was created

```bash
kubectl get namespaces
kubectl get pods -n test
```