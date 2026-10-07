### Self Signed

```bash
# Set your desired hostname (e.g., app.example.com)
HOST="*.mahinraza.online"

# Generate the self-signed certificate and key in PEM format
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=${HOST}/O=${HOST}" \
  -addext "subjectAltName = DNS:${HOST}"
```
```bash
kubectl create secret tls my-services-mahinraza-online-tls-secret \
  --cert=tls.crt \
  --key=tls.key
```

---

