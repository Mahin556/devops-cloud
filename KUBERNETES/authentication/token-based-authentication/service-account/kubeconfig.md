```bash

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: sa-demo
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mysa
  namespace: sa-demo
EOF

TOKEN=$(kubectl create token mysa -n sa-demo --duration=10m --audience="https://kubernetes.default.svc.cluster.local")

SERVER=$(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')

CACERT=$(kubectl config view --raw -ojsonpath='{.clusters[0].cluster.certificate-authority-data}')

NAMESPACE=sa-demo

mkdir -p ~/.kube/my-sa

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-node-viewer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list","get","watch"]
- apiGroups: [""]
  resources: ["nodes","nodes/status"]
  verbs: ["get","list","watch"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-node-viewer-rb
subjects:
- kind: ServiceAccount
  name: mysa
  namespace: sa-demo
roleRef:
  kind: ClusterRole
  name: pod-node-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

cat <<EOF > ~/.kube/my-sa/config
apiVersion: v1
kind: Config
clusters:
- name: kubernetes
  cluster:
    certificate-authority-data: $CACERT
    server: $SERVER
contexts:
- name: mysa-context
  context:
    cluster: kubernetes
    namespace: $NAMESPACE
    user: mysa
current-context: mysa-context
users:
- name: mysa
  user:
    token: $TOKEN
EOF

export KUBECONFIG=~/.kube/my-sa/config
kubectl get pods

unset KUBECONFIG

#OR

kubectl config set-cluster kubernetes \
  --kubeconfig=mysa.conf \
  --server="$(kubectl config view -ojsonpath='{.clusters[0].cluster.server}')" \
  --certificate-authority <(kubectl config view --raw -ojsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d) \
  --embed-certs=true


kubectl config --kubeconfig=mysa.conf set-credentials mysa \
  --token="$TOKEN"

kubectl config --kubeconfig=mysa.conf set-context mysa-context \
  --cluster=kubernetes \
  --namespace="$NAMESPACE" \
  --user=mysa

kubectl config --kubeconfig=mysa.conf use-context mysa-context

kubectl --kubeconfig mysa.conf get pods
```