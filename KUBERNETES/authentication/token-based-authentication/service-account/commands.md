```bash
kubectl create clusterrolebinding <binding-name> --clusterrole=<cluster-role-name> --user=<username>

kubectl create clusterrolebinding <binding-name> --clusterrole=<cluster-role-name> --group=<groupname>

kubectl create clusterrolebinding <binding-name> --clusterrole=<cluster-role-name> --serviceaccount=<namespace>:<serviceaccount-name>
```