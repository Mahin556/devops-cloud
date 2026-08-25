```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space1
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: space2
  - ports:
    - port: 53
      protocol: TCP
    - port: 53
      protocol: UDP
```

### Allowed ✅

* **All Pods in `space1` → All Pods in `space2`**
* **All Pods in `space1` → DNS on TCP port 53**
* **All Pods in `space1` → DNS on UDP port 53**
* Only **outgoing (Egress)** traffic is controlled.

### Denied ❌

* `space1` Pods → Pods in `space3`
* `space1` Pods → Pods in `default`
* `space1` Pods → Internet
* `space1` Pods → External IP addresses
* `space1` Pods → Any destination other than `space2` or DNS
* `space1` Pods → Other namespaces

### Not controlled ⚠️

* Incoming traffic **to** `space1` Pods
* Traffic from `space2` → `space1`
* Traffic from other namespaces → `space1`
* Egress traffic from Pods outside `space1`

### In short

```text
space1 Pods
    │
    ├──→ space2 Pods     ✅
    ├──→ DNS :53 TCP     ✅
    ├──→ DNS :53 UDP     ✅
    │
    └──→ Everything else ❌
```
