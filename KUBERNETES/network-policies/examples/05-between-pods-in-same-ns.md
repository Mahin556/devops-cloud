* By default in kubernetes all pod can communicate with each other without any restrictions.

#### Example
```bash
kubectl create namespace np-demo

kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod1
  labels:
    app: nginx-pod1
  namespace: np-demo
spec:
  containers:
    - name: nginx-container
      image: nginx:latest
      ports:
        - containerPort: 80
---

apiVersion: v1
kind: Service
metadata:
  namespace: np-demo
  name: pod1-service
spec:
  selector:
    app: nginx-pod1
  type: ClusterIP 
  ports:
    - protocol: TCP
      port: 80 
      targetPort: 80 
EOF
```

```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod2
  labels:
    app: nginx-pod2
  namespace: np-demo
spec:
  containers:
    - name: nginx-container
      image: nginx:latest
      ports:
        - containerPort: 80
---

apiVersion: v1
kind: Service
metadata:
  name: pod2-service
  namespace: np-demo
spec:
  selector:
    app: nginx-pod2
  type: ClusterIP 
  ports:
    - protocol: TCP
      port: 80 
      targetPort: 80 
EOF
```

```bash
kubectl config set-context --current --namespace np-demo

kubectl get pod

kubectl  exec -it pod1 -- /bin/sh -c "apt update && apt install telnet -y"
kubectl  exec -it pod2 -- /bin/sh -c "apt update && apt install telnet -y"

kubectl  exec -it pod1 -- /bin/sh -c "telnet pod2-service 80"
kubectl  exec -it pod2 -- /bin/sh -c "telnet pod1-service 80"
```

```bash
controlplane:~$ k exec -it pod1 -- /bin/sh -c "telnet pod2-service 80"
Trying 10.97.169.183...
Connected to pod2-service.
Escape character is '^]'.
Connection closed by foreign host.

controlplane:~$ k exec -it pod1 -- /bin/sh -c "telnet pod1-service 80"
Trying 10.98.88.100...
Connected to pod1-service.
Escape character is '^]'.
Connection closed by foreign host.
```

* Applying Network Policy to only allow the communication from `pod1` to `pod2`.

#### Example
```bash
# Pod1 can only receive packets on port 80 from pods having label(app: nginx-pod2)
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pod1-np                
  namespace: np-demo             
spec:
  policyTypes:
    - Ingress                   
    - Egress                    
  podSelector:
    matchLabels:
      app: nginx-pod1                 
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: nginx-pod2  
    ports:
    - protocol: TCP
      port: 80   
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
```bash
kubectl exec -it pod1 -- /bin/sh -c "telnet pod2-service 80" #Work✅

kubectl exec -it pod2 -- /bin/sh -c "telnet pod1-service 80" #No Work❌
```
```bash
# Update the previous policy
kubectl apply -f -<<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pod1-np                
  namespace: np-demo             
spec:
  policyTypes:
    - Ingress                   
    - Egress                    
  podSelector:
    matchLabels:
      app: nginx-pod1     
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-pod2  
    ports:
    - protocol: TCP
      port: 80   
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: nginx-pod2  
    ports:
    - protocol: TCP
      port: 80   
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
```bash
kubectl exec -it pod1 -- /bin/sh -c "telnet pod2-service 80" #Work✅

kubectl exec -it pod2 -- /bin/sh -c "telnet pod1-service 80" #Work✅
```