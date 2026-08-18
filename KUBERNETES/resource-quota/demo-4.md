### Terminating Scope
- A Pod is considered Terminating for ResourceQuota scope purposes when it has `activeDeadlineSeconds`

- In Kubernetes, `activeDeadlineSeconds` is a configuration field used to set a strict time limit (timeout) on how long a Job or a Pod is allowed to run. Once this specified duration is reached, Kubernetes automatically terminates the resource and marks its status as failed with the reason DeadlineExceeded.

```bash
cat <<EOF | tee terminating-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: terminating-pod
  namespace: quota-lab
spec:
  activeDeadlineSeconds: 60
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
cat <<EOF | tee terminating-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: terminating-quota
  namespace: quota-lab
spec:
  scopes:
    - Terminating
  hard:
    pods: "3"
EOF
```
```bash
kubectl describe resourcequota terminating-quota -n quota-lab
```