```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 8443:443 --address=0.0.0.0

curl -H "Host: demo.local" http://localhost/
curl -H "Host: demo.local" http://localhost/oldpath
curl -H "Host: demo.local" http://localhost/oldpath/
curl -H "Host: demo.local" http://localhost/newpath
curl -H "Host: demo.local" http://localhost/newpath/
curl -H "Host: demo.local" http://localhost/app/newpath/
curl -H "Host: demo.local" http://localhost/app/newpath
```