```bash
kubectl create clusterrole createpods --verb=create --resource=pods

kubectl create clusterrolebinding createpods-jane --clusterrole=createpods --user=jane

kubectl create clusterrolebinding example-masters-binding --clusterrole=cluster-admin --group=example:masters
```
```bash
k -n applications create role -h
k -n applications create rolebinding -h

k -n applications create role smoke --verb create,delete --resource pods,deployments,sts
k -n applications create rolebinding smoke --role smoke --user smoke

k -n applications create rolebinding smoke-view --clusterrole view --user smoke
k -n default create rolebinding smoke-view --clusterrole view --user smoke
k -n kube-node-lease create rolebinding smoke-view --clusterrole view --user smoke
k -n kube-public create rolebinding smoke-view --clusterrole view --user smoke
```