### NotTerminating Scope
```bash
cat <<EOF | tee not-terminating-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: not-terminating-quota
  namespace: quota-lab
spec:
  scopes:
    - NotTerminating
  hard:
    pods: "10"
EOF
```
```bash
kubectl describe resourcequota not-terminating-quota -n quota-lab
```
```bash
cat <<EOF | tee non-terminating-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: terminating-pod
  namespace: quota-lab
spec:
  containers:
    - name: busybox
      image: busybox:latest
      command:
        - sh
        - -c
        - "echo Running; sleep 120"
EOF
```
```bash
kubectl describe resourcequota not-terminating-quota -n quota-lab
```