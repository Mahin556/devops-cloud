* Username + Password (STATIC BASIC AUTH)

```bash
cat << EOF > /etc/kubernetes/password.csv
password123,dev-user,uid123,"developers"
EOF

#Configure API server
--basic-auth-file=/etc/kubernetes/password.csv
#Restart API server.

kubectl config set-credentials dev-user \
  --username=dev-user --password=password123

kubectl config get-users

kubectl --user=dev-user get pods #Works, but completely insecure.
```
