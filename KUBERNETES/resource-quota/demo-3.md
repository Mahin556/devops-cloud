### NotBestEffort Scope

NotBestEffort matches Pods that are not BestEffort, such as:
- Burstable
- Guaranteed

```bash
cat <<EOF | tee not-besteffort-quota.yaml | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: not-besteffort-quota
  namespace: quota-lab
spec:
  scopes:
    - NotBestEffort
  hard:
    pods: "10"
    requests.cpu: "10"
    requests.memory: 20Gi
EOF
```

A Pod becomes Burstable when it has at least one resource request or limit, but isn't fully Guaranteed.

```bash
cat <<EOF | tee burstable-pod.yaml | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
  namespace: quota-lab
spec:
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        requests:
          cpu: "500m"
          memory: "512Mi"
EOF
```
```bash
kubectl get pod burstable-pod \
  -n quota-lab \
  -o jsonpath='{.status.qosClass}'
```
```bash
kubectl describe resourcequota not-besteffort-quota -n quota-lab
```