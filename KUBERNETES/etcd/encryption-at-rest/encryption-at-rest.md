```bash
KEY=$(head -c 32 /dev/urandom | base64)

echo $KEY
# Z5DxgGFZ27I957FL6yhJjSa/9FMkCFUjSHPyeyJZpE4=

cat << EOF > encryptionconfig.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: ${KEY}
    - identity: {}
EOF

cp encryptionconfig.yaml /etc/kubernetes/pki/

cat /etc/kubernetes/pki/encryptionconfig.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
```
```yaml
---
#
# This is a fragment of a manifest for a static Pod.
# Check whether this is correct for your cluster and for your API server.
#
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 10.20.30.40:443
  creationTimestamp: null
  labels:
    app.kubernetes.io/component: kube-apiserver
    tier: control-plane
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    ...
    - --encryption-provider-config=/etc/kubernetes/pki/encryptionconfig.yaml  # add this line
    volumeMounts:
    ...
    - name: enc                           # add this line
      mountPath: /etc/kubernetes/enc      # add this line
      readOnly: true                      # add this line
    ...
  volumes:
  ...
  - name: enc                             # add this line
    hostPath:                             # add this line
      path: /etc/kubernetes/enc           # add this line
      type: DirectoryOrCreate             # add this line
  ...
```
```bash
kubectl create secret generic second --from-literal=anotherkey=anothervalue

kubectl get secret second -ojsonpath="{.data.anotherkey}" | base64 --decode ; echo

# Unencrypted first secret
kubectl exec -it -n kube-system etcd-demo-control-plane --   etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/server.crt   --key=/etc/kubernetes/pki/etcd/server.key  get /registry/secrets/default/first

# Encrypted second secret
kubectl exec -it -n kube-system etcd-demo-control-plane --   etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/server.crt   --key=/etc/kubernetes/pki/etcd/server.key  get /registry/secrets/default/second
```

### Encrypting already created secrets
```bash
kubectl get secret --all-namespaces -oyaml | kubectl replace -f -
```
```bash
# Encrypted first secret
kubectl exec -it -n kube-system etcd-demo-control-plane --   etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/server.crt   --key=/etc/kubernetes/pki/etcd/server.key  get /registry/secrets/default/first
```