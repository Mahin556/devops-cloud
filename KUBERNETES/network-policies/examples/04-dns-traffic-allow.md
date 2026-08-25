### DEFAULT DENY

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

kubectl get networkpolicy
```

### Allowed ✅

* Nothing by default
* Other NetworkPolicies can explicitly allow traffic

### Denied ❌

* Any Pod → Any Pod
* External traffic → Any Pod
* Any Pod → Internet
* Any Pod → External IP addresses
* Any Pod → DNS/CoreDNS
* All **incoming (Ingress)** traffic
* All **outgoing (Egress)** traffic

### Not controlled ⚠️

* Traffic in other namespaces
* Traffic allowed by other NetworkPolicies


---

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-traffic-for-frontend
  namespace: default
spec:
  podSelector: 
    matchLabels:
      run: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          run: backend
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchExpressions:
        - key: k8s-app
          operator: In
          values: ["coredns", "kube-dns"]
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
EOF
```

##### Allowed ✅

* Frontend Pods → Backend Pods (`run=backend`) in the **default namespace**
* Frontend Pods → **All ports** on the allowed destinations
* Only **outgoing (egress)** traffic is controlled

##### Denied ❌

* Frontend → Other Pods in the default namespace
* Frontend → Pods in namespaces without `ns=cassandra`
* Frontend → Internet
* Frontend → External IP addresses
* Frontend → Any destination not explicitly allowed
* Frontend → DNS/CoreDNS, unless another NetworkPolicy allows DNS

##### Not controlled ⚠️

* Traffic **coming into** frontend Pods
* Backend → Frontend
* Other Pods → Frontend

---

```bash
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-traffic-for-backend
  namespace: default
spec:
  podSelector: 
    matchLabels:
      run: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: frontend
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          ns: cassandra
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        # matchLabels:
        #   k8s-app: kube-dns
        matchExpressions:
        - key: k8s-app
          operator: In
          values: ["coredns", "kube-dns"]
    ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
EOF
```

### Allowed ✅

* **Frontend Pods → Backend Pods** (`run=backend`) in the **default namespace**
* **Backend Pods → Pods** in namespaces labeled `ns=cassandra`
* Backend → Cassandra traffic on **all ports**
* Frontend → Backend traffic on **all ports**

### Denied ❌

* Any Pod other than `run=frontend` → Backend
* Backend → Any Pod other than those in `ns=cassandra`
* Backend → Internet
* Backend → External IP addresses
* Backend → Other namespaces without `ns=cassandra`
* Backend → DNS/CoreDNS, unless another NetworkPolicy allows it

### Not controlled ⚠️

* Traffic to/from **Pods other than `run=backend`**
* Frontend's outgoing traffic to other destinations
* Cassandra's incoming/outgoing traffic
* Traffic in other namespaces unless they have their own policies

---

```bash
kubectl create ns cassandra
kubectl label ns cassandra ns=cassandra
kubectl label ns default ns=default

kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-traffic-for-cassandra
  namespace: cassandra
spec:
  podSelector:
    matchLabels:
      run: cassandra
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          ns: default
      podSelector:
        matchLabels:
          run: backend
EOF
```

### Allowed ✅

* Backend Pods in the `default` namespace with `run=backend` → Pods in the `cassandra` namespace with labels `run=cassandra`
* Only **incoming (Ingress)** traffic is controlled
* All ports are allowed because no `ports:` rule is specified

### Denied ❌

* Pods from namespaces other than **`default`** → Cassandra Pods
* Pods from other namespaces → Cassandra Pods
* External traffic → Cassandra Pods, unless another policy allows it
* Any source not matching `ns: default`

### Not controlled ⚠️

* Cassandra Pods → Other Pods
* Cassandra Pods → Internet
* Cassandra Pods → External IPs
* Outgoing (**Egress**) traffic from Cassandra Pods
* Traffic to Pods outside the Cassandra namespace

---

```bash
kubectl run frontend --image=nginx
kubectl run backend --image=nginx
kubectl run cassandra --image=nginx --namespace cassandra

kubectl expose pod frontend --port=80
kubectl expose pod backend --port=80
kubectl expose pod cassandra -n cassandra --port=80

kubectl wait --for=condition=Ready pod -l run=frontend
kubectl wait --for=condition=Ready pod -l run=backend
kubectl wait --for=condition=Ready pod -l run=cassandra --namespace cassandra

FRONTEND_IP=$(kubectl get pod frontend -ojsonpath='{.status.podIP}')
BACKEND_IP=$(kubectl get pod backend -ojsonpath='{.status.podIP}')
CASSANDRA_IP=$(kubectl get pod cassandra --namespace cassandra -ojsonpath='{.status.podIP}')

echo $FRONTEND_IP
echo $BACKEND_IP
echo $CASSANDRA_IP

kubectl exec frontend -- curl backend #WORK
kubectl exec backend -- curl frontend #FAIL
kubectl exec backend -- curl cassandra.cassandra #WORK

kubectl exec frontend -- curl ${BACKEND_IP} #WORK
kubectl exec backend -- curl ${FRONTEND_IP} #FAIL

kubectl exec frontend -- curl ${CASSANDRA_IP} #FAIL
kubectl exec backend -- curl ${CASSANDRA_IP} #WORK
```