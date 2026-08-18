```bash
kubectl apply -f daemonset.yaml
kubectl get daemonset
kubectl get daemonset -A
kubectl describe daemonset <daemonset_name>
kubectl delete daemonset <daemonset_name>
kubectl edit daemonset <daemonset_name>
kubectl describe ds <daemonset_name> -n <ns>
kubectl rollout restart daemonset/<daemonset_name>
kubectl rollout status daemonset/<daemonset_name>
```