```bash
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kube-demo
  namespace: dev2
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: dev1
    ports:
    - protocol: TCP
      port: 80
EOF
```
```bash
kubectl run http-echo \
  --image=hashicorp/http-echo \
  -n dev2 \
  -- --listen=:8080 --text="Hello from http-echo"

kubectl expose pod http-echo -n dev2 --port=8080

kubectl get svc -n dev2
```
```bash
kubectl exec nginx1 -n dev1 -- curl --connect-timeout 5 10.110.92.67:8080
```