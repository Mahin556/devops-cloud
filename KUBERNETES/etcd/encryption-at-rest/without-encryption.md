```bash
k create secret generic first --from-literal=key=value 
k get secret first -oyaml

kubectl exec -it -n kube-system etcd-demo-control-plane --   etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt   --key=/etc/kubernetes/pki/apiserver-etcd-client.key  get /registry/secrets/default/first

kubectl exec -it -n kube-system etcd-demo-control-plane --   etcdctl   --endpoints=https://127.0.0.1:2379   --cacert=/etc/kubernetes/pki/etcd/ca.crt   --cert=/etc/kubernetes/pki/etcd/server.crt   --key=/etc/kubernetes/pki/etcd/server.key  get /registry/secrets/default/first

```