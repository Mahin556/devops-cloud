```bash
kubectl scale deployment/demo --replicas 4
kubectl scale deployment/demo --replicas 0 # stop application

# To scale multiple named Deployments
kubectl scale deployment/demo deployment/demo-1 deployment/demo-2 --replicas 5

# Scale all the Deployments in a namespace
kubectl scale deployment -n default --all --replicas 5

# Scale matching Deployments by label 
kubectl scale deployment --replicas 5 -l app=demo-app

# Scale Deployments defined by YAML manifests in the manifests/ directory
kubectl scale deployment --replicas 5 -f manifests\

# Scale statefullesets
kubectl scale sts database --replicas 3

# Scale RS
kubectl scale rs database --replicas 3