```bash
openssl genrsa -out dev-user.key 2048

openssl req -new -key dev-user.key -out dev-user.csr \
  -subj "/CN=dev-user/O=developers"

openssl x509 -req -in dev-user.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out dev-user.crt -days 365

kubectl config set-credentials dev-user \
  --client-certificate=dev-user.crt \
  --client-key=dev-user.key

kubectl --user=dev-user get pods
```