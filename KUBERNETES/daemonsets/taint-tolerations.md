#### Taint-toleration
```bash
kubectl taint nodes k8s-worker-2 app=fluentd-logging:NoExecute
kubectl describe node k8s-worker-2 | grep Taints
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      tolerations:
      - key: "app"
        operator: "Equal"
        value: "fluentd-logging"
        effect: "NoExecute"
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
```
```bash
kubectl apply -f fluentd-daemonset.yaml
kubectl get pods -o wide -n kube-system -l app=fluentd
```
* This allows **Fluentd pods** to still run on `k8s-worker-2` despite the taint.
* If you **remove this toleration**, the DaemonSet pod running on `k8s-worker-2` will be evicted (as you noticed).