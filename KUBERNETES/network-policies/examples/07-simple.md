```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space2
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: space1
```

### Allowed ✅

* Pods in **`space1` → all Pods in `space2`**
* All ports are allowed because no `ports:` restriction is specified.
* Only **Ingress** traffic to Pods in `space2` is controlled.

### Denied ❌

* Pods from `space3` → Pods in `space2`
* Pods from `default` → Pods in `space2`
* Pods from any other namespace → Pods in `space2`
* External traffic → Pods in `space2`
* Any source that is **not in `space1`**

### Not controlled ⚠️

* `space2` Pods → other Pods (**Egress is not controlled**)
* `space2` Pods → Internet
* `space2` Pods → external IPs
* Traffic to Pods in other namespaces

### In short

```text
space1 Pods  ─────→  space2 Pods   ✅
space3 Pods  ─────→  space2 Pods   ❌
default Pods ─────→  space2 Pods   ❌
Internet     ─────→  space2 Pods   ❌
```

`podSelector: {}` means **all Pods in `space2`** are protected by this policy.
