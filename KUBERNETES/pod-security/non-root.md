```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod-1
spec:
  securityContext:
    runAsUser: 1000
  containers:
    - name: app
      image: ubuntu
      command: ["sh", "-c", "sleep 3600"]
EOF

kubectl get po -n default

kubectl delete pod/secure-pod-1
```
```bash
kubectl exec -it pods/secure-pod-1 -- bash

kubectl exec -it pods/secure-pod-1 -- id #1000(ubuntu)

kubectl exec -it pods/secure-pod-1 -- ls /

kubectl exec -it pods/secure-pod-1 -- touch demo #can modify root FS

kubectl wait --for=condition=Ready pod/secure-pod-1

kubectl exec -it pods/secure-pod-1 -- bash -c "apt update && apt install -y nginx curl && nginx -g 'daemon on;' && curl localhost" #Permission denied
```
We are setting non-root user in kubernetes menifest

We can also set non-root user in dockerfile itself
```bash
docker build -t non-root-ubuntu-image . -f -<<EOF
FROM ubuntu:24.04

#Run as non-root user
RUN groupadd app && useradd -m -u 1001 -g app app
RUN mkdir -p /app && chown -R app:app /app
USER app

WORKDIR /app

#Run the Flask application
CMD ["sleep", "3600"]
EOF

kind load docker-image non-root-ubuntu-image --name my-cluster
```
```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod-2
spec:
  # securityContext:
  #   runAsUser: 1000
  containers:
    - name: app
      image: non-root-ubuntu-image
      command: ["sh", "-c", "sleep 3600"]
      imagePullPolicy: Never
EOF

kubectl get po -n default

kubectl delete pod/secure-pod-2
```
```bash
kubectl exec -it pods/secure-pod-2 -- bash

kubectl exec -it pods/secure-pod-2 -- id #1000(ubuntu)

kubectl exec -it pods/secure-pod-2 -- ls /

kubectl exec -it pods/secure-pod-2 -- touch demo #can modify root FS

kubectl wait --for=condition=Ready pod/secure-pod-2

kubectl exec -it pods/secure-pod-2 -- bash -c "apt update && apt install -y nginx curl && nginx -g 'daemon on;' && curl localhost" #Permission denied
```