```bash
helm create hellworld

cat <<EOF > helmfile.yaml
---
releases:
  - name: helloworld
    chart: ./helloworld
    installed: true #false - if not want to install it
EOF

helmfile sync 
# Building dependency release=helloworld, chart=helloworld
# Affected releases are:
#   helloworld (helloworld) UPDATED

# Upgrading release=helloworld, chart=helloworld
# Release "helloworld" does not exist. Installing it now.
# NAME: helloworld
# LAST DEPLOYED: Sun Oct 17 19:53:41 2021
# NAMESPACE: default
# STATUS: deployed
# REVISION: 1
# NOTES:
# 1. Get the application URL by running these commands:
#   export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=helloworld,app.kubernetes.io/instance=helloworld" -o jsonpath="{.items[0].metadata.name}")
#   export CONTAINER_PORT=$(kubectl get pod --namespace default $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
#   echo "Visit http://127.0.0.1:8080 to use your application"
#   kubectl --namespace default port-forward $POD_NAME 8080:$CONTAINER_PORT

# Listing releases matching ^helloworld$
# helloworld	default  	1       	2021-10-17 19:53:41.44402394 +0000 UTC	deployed	helloworld-0.1.0	1.16.0

# UPDATED RELEASES:
# NAME         CHART        VERSION
# helloworld   helloworld     0.1.0 

helm list -A

cat <<EOF > helmfile.yaml
---
releases:
  - name: helloworld
    chart: ./helloworld
    installed: false
EOF

helmfile sync  
```