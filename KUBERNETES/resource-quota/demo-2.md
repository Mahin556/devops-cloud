### BestEffort Scope
A Pod gets BestEffort QoS when it has no CPU or memory requests/limits.
```bash
cat <<EOF | tee besteffort-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-pod
  namespace: quota-lab
spec:
  containers:
    - name: nginx
      image: nginx:latest
EOF
```
```bash
kubectl get pod besteffort-pod \
  -n quota-lab \
  -o jsonpath='{.status.qosClass}'
```
```bash
cat <<EOF | tee besteffort-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: besteffort-quota
  namespace: quota-lab
spec:
  scopes:
    - BestEffort
  hard:
    pods: "2"
EOF
```
```bash
kubectl describe resourcequota besteffort-quota \
  -n quota-lab
```
```bash
cat <<EOF | tee besteffort-pods.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-2
  namespace: quota-lab
spec:
  containers:
    - name: nginx
      image: nginx:latest
---
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-3
  namespace: quota-lab
spec:
  containers:
    - name: nginx
      image: nginx:latest
EOF
```
```bash
pod/besteffort-2 created
Error from server (Forbidden): error when creating "STDIN": pods "besteffort-3" is forbidden: exceeded quota: besteffort-quota, requested: pods=1, used: pods=2, limited: pods=2
```