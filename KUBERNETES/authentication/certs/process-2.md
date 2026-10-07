```bash
openssl genrsa -out david.key 2048

openssl req -new -key david.key -subj "/CN=david/O=developer" -out david.csr

cat <<EOF> file.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: <name>
spec:
  request: <csr-base64>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 8640000   # minimum - 600sec/10min
  usages:
  - client auth
EOF

CSR_david=$(cat david.csr | base64 -w 0)

curl https://raw.githubusercontent.com/shamimice03/Kubernetes_RBAC/main/CertificateSigningRequest-Template.yaml | sed "s/<name>/david/ ; s/<csr-base64>/$CSR_david/" > david_csr.yaml

kubectl create -f david_csr.yaml

kubectl get csr

kubectl describe csr david

kubectl certificate approve david

kubectl get csr <CSR-NAME> -o jsonpath='{.status.certificate}' | base64 --decode > <client-name>.crt

kubectl config view --raw -o jsonpath='{..cluster.certificate-authority-data}' | base64 --decode > ca.crt

openssl x509 -in david.crt -text -noout
openssl x509 -in ca.crt -text -noout

cat <<EOF>config
#kubeconfig file template
apiVersion: v1
kind: Config
current-context: <context>
clusters:
- name: <cluster-name>
  cluster:
    certificate-authority-data: <ca.crt>
    server: <cluster-endpoint>
contexts:
- name: <context>
  context:
    cluster: <cluster-name>
    user: <user-name>
    namespace: <namespace>
users:
- name: <user-name>
  user:
    client-certificate-data: <user.crt>
    client-key-data: <user.key>
EOF

CA_CRT=$(cat ca.crt | base64 -w 0)
CONTEXT=$(kubectl config current-context)
CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="'"$CONTEXT"'")].cluster.server}')
USER=david
NAMESPACE=production
DAVID_CRT=$(cat david.crt | base64 -w 0)
DAVID_KEY=$(cat david.key | base64 -w 0)

curl https://raw.githubusercontent.com/shamimice03/Kubernetes_RBAC/main/kubeconfig-template.yaml | 
sed "s#<context>#$CONTEXT# ;
s#<cluster-name>#$CONTEXT# ;
s#<ca.crt>#$CA_CRT# ;
s#<cluster-endpoint>#$CLUSTER_ENDPOINT# ;
s#<user-name>#$USER# ;
s#<namespace>#$NAMESPACE# ;
s#<user.crt>#$DAVID_CRT# ; 
s#<user.key>#$DAVID_KEY#" > config
```