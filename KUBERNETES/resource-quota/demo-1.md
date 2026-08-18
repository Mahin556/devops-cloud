### PriorityClass Scope

```bash
kubectl create namespace quota-lab
```
```bash
cat <<EOF | tee priority-classes.yaml | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 100000
globalDefault: false
description: "High priority workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 1000
globalDefault: false
description: "Low priority workloads"
EOF
```
```bash
kubectl get priorityclass
```
```bash
cat <<EOF | tee high-priority-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: high-priority-quota
  namespace: quota-lab
spec:
  scopeSelector:
    matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values:
          - high-priority
  hard:
    pods: "5"
    requests.cpu: "10"
    requests.memory: 10Gi
EOF
```
```bash
kubectl get resourcequota -n quota-lab
```
```bash
kubectl describe resourcequota high-priority-quota -n quota-lab
```
```bash
cat <<EOF | tee high-priority-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-pod-1
  namespace: quota-lab
spec:
  priorityClassName: high-priority
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        requests:
          cpu: "100m"
          memory: "100Mi"
EOF
```
```bash
kubectl get pods -n quota-lab
```
```bash
kubectl describe resourcequota high-priority-quota -n quota-lab
```
```bash
cat <<EOF | tee high-priority-deployment.yaml | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: high-priority-app
  namespace: quota-lab
spec:
  replicas: 4
  selector:
    matchLabels:
      app: high-priority
  template:
    metadata:
      labels:
        app: high-priority
    spec:
      priorityClassName: high-priority
      containers:
        - name: nginx
          image: nginx:latest
          resources:
            requests:
              cpu: "100m"
              memory: "100Mi"
EOF
```
```bash
kubectl get pods -n quota-lab
```
```bash
kubectl describe resourcequota high-priority-quota -n quota-lab
```
```bash
cat <<EOF | tee high-pod-6.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: high-pod-6
  namespace: quota-lab
spec:
  priorityClassName: high-priority
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        requests:
          cpu: "1"
          memory: "1Gi"
EOF
# Error from server (Forbidden): error when creating "STDIN": pods "high-pod-6" is forbidden: exceeded quota: high-priority-quota, requested: pods=1, used: pods=5, limited: pods=5
```
```bash
cat <<EOF | tee low-priority-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: low-pod-1
  namespace: quota-lab
spec:
  priorityClassName: low-priority
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        requests:
          cpu: "100m"
          memory: "100Mi"
EOF
```
```bash
kubectl get pods -n quota-lab
```
```bash
cat <<EOF | tee low-priority-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: low-priority-quota
  namespace: quota-lab
spec:
  scopeSelector:
    matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values:
          - low-priority
  hard:
    pods: "10"
    requests.cpu: "5"
    requests.memory: 5Gi
EOF
```
```bash
kubectl describe resourcequota low-priority-quota -n quota-lab
```