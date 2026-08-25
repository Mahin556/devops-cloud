```bash
# Generate the private key and self-signed CA certificate:
openssl req \
  -x509 \
  -newkey rsa:4096 \
  -sha256 \
  -days 365 \
  -nodes \
  -keyout ca.key \
  -out ca.crt \
  -subj "/CN=My-Kubernetes-CA" \
  -extensions v3_ca

openssl x509 -in ca.crt -text -noout

# Generate the Server Private Key
openssl genrsa -out server.key 4096

# Create a Server CSR with SAN - Create a configuration file.
cat > server.cnf <<EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = ingress-domain.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ingress-domain.com
DNS.2 = *.ingress-domain.com
EOF

# Generate the CSR:
openssl req \
  -new \
  -key server.key \
  -out server.csr \
  -config server.cnf

# Sign the Server Certificate
openssl x509 \
  -req \
  -in server.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out server.crt \
  -days 365 \
  -sha256 \
  -extensions req_ext \
  -extfile server.cnf

openssl x509 -in server.crt -text -noout

# Generate the Client Private Key
openssl genrsa -out client.key 4096

# Create Client CSR with SAN
cat > client.cnf <<EOF
[req]
default_bits = 4096
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = Mahin

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = Mahin
EOF

# Generate the CSR:
openssl req \
  -new \
  -key client.key \
  -out client.csr \
  -config client.cnf

# Sign the Client Certificate
openssl x509 \
  -req \
  -in client.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out client.crt \
  -days 365 \
  -sha256 \
  -extensions req_ext \
  -extfile client.cnf

openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt client.crt
```
```bash
# Create Kubernetes Secrets
# Server TLS Secret
kubectl create secret tls tls-secret \
  --cert=server.crt \
  --key=server.key

# CA Secret
kubectl create secret generic ca-secret \
  --from-file=ca.crt=ca.crt

kubectl get secret
```
```bash
curl \
-H "Host: ingress-domain.comv" \
http://localhost:8443/

# 401 Unauthorizedv
```
```bash
curl \
-H "Host: ingress-domain.com" \
https://localhost:8443/ \
--cert client.crt \
--key client.key

# HTTP/1.1 200 OK
```