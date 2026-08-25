I'll simulate a multi-tier microservice architecture where `level: 100x` represents a **"Reporting Aggregator"** microservice that needs to pull metrics from its peer replicas deployed across three different environment zones (`level-1000`, `level-1001`, `level-1002`). 

---

### Scenario Setup
- **Source Pod** (`level: 100x`) in the `default` namespace. This is your main application.
- **Target Pods** (`level: 100x`) in namespaces `level-1000`, `level-1001`, and `level-1002`. These are your data shards.
- **Forbidden Pod**: A random Nginx server on the public internet (`1.1.1.1`).

---

### Step 1: Create the Environment (Prerequisites)

```bash
# 1. Create the 3 target namespaces and label them
kubectl create ns level-1000
kubectl label ns level-1000 kubernetes.io/metadata.name=level-1000

kubectl create ns level-1001
kubectl label ns level-1001 kubernetes.io/metadata.name=level-1001

kubectl create ns level-1002
kubectl label ns level-1002 kubernetes.io/metadata.name=level-1002

# 2. Create a "target" pod in level-1000 (matching the policy)
kubectl run target-pod-1 -n level-1000 --image=nginx --labels="level=100x" --expose --port=80

# 3. Create a "target" pod in level-1001 (matching the policy)
kubectl run target-pod-2 -n level-1001 --image=nginx --labels="level=100x" --expose --port=80

# 4. Create the "source" pod in default (matching the policy)
kubectl run source-pod -n default --image=nicolaka/netshoot --labels="level=100x" -- sleep infinity

# 5. Create a decoy pod in level-1000 that does NOT match the label (to prove it gets blocked)
kubectl run decoy-pod -n level-1000 --image=nicolaka/netshoot --labels="app=random" --expose --port 80 -- sleep infinity
```

---

### Step 2: Apply the Policy

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-100x
  namespace: default
spec:
  podSelector:
    matchLabels:
      level: 100x
  policyTypes:
  - Egress
  egress:
  # Rule 1: Allow to peer pods in level-1000
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: level-1000
      podSelector:
        matchLabels:
          level: 100x
  # Rule 2: Allow to peer pods in level-1001
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: level-1001
      podSelector:
        matchLabels:
          level: 100x
  # Rule 3: Allow to peer pods in level-1002
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: level-1002
      podSelector:
        matchLabels:
          level: 100x
  # Rule 4: Allow DNS to ANYWHERE (port 53)
  - ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```
---

### Step 3: Detailed Testing (What Works vs. What Fails)

#### ✅ Test 1: Reach the allowed peer (WORKS)
```bash
# Access the pod in level-1000 via its Kubernetes Service
kubectl exec -it source-pod -n default -- /bin/bash -c 'curl -v target-pod-1.level-1000.svc.cluster.local:80'
```
**Result**: `Connection established` (200 OK).  
**Why**: Matches **Rule 1** (Namespace `level-1000` + Pod label `level: 100x`). No port restriction means port 80 is allowed.

---

#### ✅ Test 2: DNS Resolution (WORKS)
```bash
kubectl exec -it source-pod -n default -- /bin/bash -c 'nslookup google.com'
```
**Result**: Returns IP addresses.  
**Why**: Matches **Rule 4** (UDP 53 to anywhere). Even though we don't explicitly allow `kube-system`, this rule lets it reach CoreDNS via the cluster IP.

---

#### ❌ Test 3: Reach the decoy pod in level-1000 (FAILS)
```bash
# Try to reach the decoy pod
kubectl exec -it source-pod -n default -- /bin/bash -c 'curl -v decoy-pod.level-1000.svc.cluster.local:80'
```
**Result**: `Connection timed out` (hangs).  
**Why**: The decoy has `app=random`, **not** `level: 100x`. The policy explicitly requires the destination pod to have `level: 100x`. Since it doesn't, Calico drops the packets.

---

#### ❌ Test 4: Reach the public Internet (FAILS)
```bash
# Try to fetch a webpage from a public IP
kubectl exec -it source-pod -n default -- /bin/bash -c 'curl -v 1.1.1.1:80'
```
**Result**: `No route to host` or `Connection timed out`.  
**Why**: Doesn't match Rules 1-3 (wrong namespace/pod labels). Doesn't match Rule 4 (port 80, not 53). Therefore, blocked.

---

#### ❌ Test 5: Reach the Kubernetes API (FAILS)
```bash
# Try to read the kubernetes service
kubectl exec -it source-pod -n default -- /bin/bash -c 'curl -vk https://kubernetes.default.svc.cluster.local:443'
```
**Result**: `curl: (28) Failed to connect to ... port 443: Connection timed out`.  
**Why**: The API server is in `kube-system`, which is not listed in Rules 1-3, and port 443 is not port 53. This is a **huge trap**—your application cannot query the API to read Secrets/ConfigMaps!

---

#### ✅ Test 6: Ingress (Incoming Traffic) is WIDE OPEN
Even though egress is strict, **ingress is unrestricted**. If another pod (even without labels) tries to connect *to* the `source-pod`, it will succeed.
```bash
# From your local machine or another pod, run:
kubectl run attacker-pod --image=nicolaka/netshoot --rm -it --restart=Never -- /bin/bash -c 'curl -v source-pod.default.svc.cluster.local:80'
```
**Result**: `Connection established`.  
**Why**: You didn't define `ingress` rules, and you didn't include `Ingress` in `policyTypes` (only `Egress` is listed). So ingress defaults to "Allow All".

---

### Summary Table of Behaviors

| Destination | Protocol/Port | Match? | Result |
| :--- | :--- | :--- | :--- |
| `level-1000` pod (label `level:100x`) | Any Port | ✅ Rule 1 | **Allowed** |
| `level-1001` pod (label `level:100x`) | Any Port | ✅ Rule 2 | **Allowed** |
| `level-1002` pod (label `level:100x`) | Any Port | ✅ Rule 3 | **Allowed** |
| CoreDNS (Cluster IP) | UDP 53 | ✅ Rule 4 | **Allowed** |
| Google DNS (8.8.8.8) | UDP 53 | ✅ Rule 4 | **Allowed** |
| `level-1000` decoy pod (`app:random`) | Any Port | ❌ No match | **Blocked** |
| Public Internet (1.1.1.1) | TCP 80 | ❌ No match | **Blocked** |
| Kubernetes API Server | TCP 443 | ❌ No match | **Blocked** |
| Any Pod (Incoming) | Any Port | N/A (no Ingress) | **Allowed** |

---

### Pro-Tip: Tightening this Policy (Security Improvement)
In a production environment, allowing DNS to *anywhere* (Rule 4) is a minor security risk (DNS tunneling). 

Instead, restrict DNS **only** to your CoreDNS pods:
```yaml
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns  # Standard CoreDNS label in Kind
    ports:
    - protocol: UDP
      port: 53
```

And if your app needs the Kubernetes API, add a 5th rule targeting `kube-system` pods with the label `component: kube-apiserver` on port `6443`.