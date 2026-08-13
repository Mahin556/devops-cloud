```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  containers:
    - name: app
      image: ubuntu
      command: ["sh", "-c", "sleep 3600"]
EOF

kubectl get po -n default

kubectl delete pod/insecure-pod
```
```bash
kubectl exec -it pods/insecure-pod -- bash

kubectl exec -it pods/insecure-pod -- id #root(0)

kubectl exec -it pods/insecure-pod -- ls /

kubectl exec -it pods/insecure-pod -- touch demo #can modify root FS

kubectl wait --for=condition=Ready pod/insecure-pod

kubectl exec -it pods/insecure-pod -- bash -c "apt update && apt install -y nginx curl && nginx -g 'daemon on;' && curl localhost" #Can install anything(malware wtc)
```