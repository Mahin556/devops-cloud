## ExternalName
Create database and app namespaces 
```
kubectl create ns database-ns
kubectl create ns application-ns
```
Create the databas pod and service
```
kubectl apply -f db.yaml
kubectl apply -f db_svc.yaml
```
Create ExternalName service
```
kubectl apply -f externam-db_svc.yaml
```
Create Application to access the service
Docker build
`docker build --no-cache --platform=linux/amd64 -t ttl.sh/saiyamdemo:1h . `

Docker push 
`docker push ttl.sh/saiyamdemo:1h`

`kubectl apply -f apppod.yaml`

Check the pod logs to see if the connection was successful 

`kubectl logs my-application -n application-ns`