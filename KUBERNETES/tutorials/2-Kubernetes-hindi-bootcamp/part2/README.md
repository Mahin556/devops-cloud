## Kubernetes Architecture 
First we will discuss Kubernetes Architecture and try to understand what happens under the hood when you run:
```bash
kubectl run nginx --image=nginx
```

## Create CSR
```bash
openssl genrsa -out mahin.key 2048 && ls
openssl req -new -key mahin.key -out mahin.csr -subj "/CN=mahin/O=group1" && ls
```
## Sign CSE with Kubernetes CA
```bash
cat mahin.csr | base64 | tr -d '\n'
```

```bash
kubectl apply -f -<<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: mahin
spec:
  request: $(cat mahin.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```
```bash
kubectl get certificatesigningrequests
#or
kubectl get csr
kubectl get certificate --all-namespaces

kubectl certificate approve mahin

kubectl get csr mahin -o jsonpath='{.status.certificate}' | base64 --decode > mahin.crt && ls
```


## Role and role binding
```bash
kubectl apply -f -<<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: mahin
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```
```bash
kubectl get role -n default
kubectl get rolebinding -n default
```

### setup kubeconfig
```bash
kubectl config view
kubectl config view --raw

kubectl config set-credentials mahin --client-certificate=mahin.crt --client-key=mahin.key
kubectl config get-contexts
kubectl config set-context mahin-context --cluster=kubernetes --namespace=default --user=mahin
kubectl config use-context mahin-context

# New config file
kubectl config set-credentials mahin --client-certificate=mahin.crt --client-key=mahin.key --embed-certs=true --kubeconfig=config && cat config

APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') && echo $APISERVER

kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt  && cat ca.crt

kubectl config set-cluster mahin --server=$(echo ${APISERVER}) --certificate-authority=ca.crt --embed-certs=true --kubeconfig config && cat config

kubectl config set-context mahin@kubernetes --cluster=mahin --user=mahin --namespace=default --kubeconfig config && cat config 

kubectl config get-contexts --kubeconfig config

kubectl config use-context mahin@kubernetes --kubeconfig config && kubectl config get-contexts --kubeconfig config

kubectl get pod --kubeconfig config

kubectl auth whoami --kubeconfig config

kubectl config set-context --current --namespace kube-system
```

### Merging multiple KubeConfig files
```bash
export KUBECONFIG=/path/to/first/config:/path/to/second/config:/path/to/third/config
```

### Create a file deploy.json
```bash 
kubectl create deployment nginx --image=nginx --dry-run=client -o json > deploy.json
kubectl run nginx --image=nginx --dry-run=client -o json
```

### SA creation
```bash
kubectl create serviceaccount mahin --namespace default

kubectl create clusterrolebinding mahin-clusteradmin-binding --clusterrole=cluster-admin --serviceaccount=default:mahin

TOKEN=$(kubectl create token mahin) && echo ${TOKEN}

APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') && echo ${APISERVER}

#List deployments
curl -X GET $APISERVER/apis/apps/v1/namespaces/default/deployments -H "Authorization: Bearer $TOKEN" -k

#Create Deployment
curl -X POST $APISERVER/apis/apps/v1/namespaces/default/deployments \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d @deploy.json \
  -k

#List pods 
curl -X GET $APISERVER/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $TOKEN" \
  -k  

curl -X GET $APISERVER/api/v1 \
  -H "Authorization: Bearer $TOKEN" \
  -k  

curl -X GET $APISERVER/api \
  -H "Authorization: Bearer $TOKEN" \
  -k  

curl -X GET $APISERVER/apis \
  -H "Authorization: Bearer $TOKEN" \
  -k 

curl -X GET $APISERVER/apis/apps \
  -H "Authorization: Bearer $TOKEN" \
  -k  

curl -X GET $APISERVER/apis/apps/v1 \
  -H "Authorization: Bearer $TOKEN" \
  -k  
```

```bash
kubectl proxy

curl localhost:8001/apis
```