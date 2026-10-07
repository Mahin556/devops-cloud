* Bearer Token (SERVICE ACCOUNT TOKEN)

```bash
kubectl create serviceaccount myapp-sa

kubectl create token myapp-sa
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

curl -H "Authorization: Bearer <TOKEN>" \
  --cacert /etc/kubernetes/pki/ca.crt \
  https://<api-server>/api/v1/pods

kubectl config set-credentials sa-user --token=<TOKEN>

kubectl --user=sa-user get pods
```