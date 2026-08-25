```bash
htpasswd -c auth kube
kubectl create secret generic basic-auth \
  --from-file=auth
kubectl describe secret basic-auth
```
```bash
curl \
-H "Host: app.example.com" \
http://localhost:8080/

# 401 Unauthorizedv
```
```bash
curl \
-u kube:kube \
-H "Host: app.example.com" \
http://localhost:8080/

# HTTP/1.1 200 OK
```