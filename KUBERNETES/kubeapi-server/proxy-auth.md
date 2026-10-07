### References:
- https://youtu.be/cywZpjKOegE?si=fOqYC8ou5CevO8W-

---

```bash
A) ENABLE PROXY AUTH ON API SERVER
(Requires control-plane access)

Edit kube-apiserver manifest:
vim /etc/kubernetes/manifests/kube-apiserver.yaml

Add flags:
--requestheader-username-headers=X-Remote-User
--requestheader-group-headers=X-Remote-Group
--requestheader-extra-headers-prefix=X-Remote-Extra-
--requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
--requestheader-allowed-names=front-proxy-client

Files required:
front-proxy-ca.crt
front-proxy-client.crt
front-proxy-client.key

Restart happens automatically (static pod)
kubectl get pods -n kube-system | grep apiserver
────────────────────────
```

```
B) CONFIGURE A REVERSE PROXY (NGINX EXAMPLE)

Install nginx:
sudo apt install nginx -y

Edit config:
sudo vim /etc/nginx/conf.d/k8s-proxy.conf

Paste:
server {
    listen 8443;
    server_name _;

    location / {
        proxy_set_header X-Remote-User mahin;
        proxy_set_header X-Remote-Group dev-team;
        proxy_pass https://<API-SERVER-IP>:6443;
    }
}

Restart nginx:
sudo systemctl restart nginx

Test:
curl -k https://localhost:8443/api
────────────────────────
```

```
C) CREATE RBAC TO MATCH HEADER USER

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: proxy-user-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: mahin
  apiGroup: rbac.authorization.k8s.io
EOF

Verify:
kubectl auth can-i list pods --as=mahin  # expected: yes
────────────────────────
```

```
D) ACCESS API VIA PROXY

curl -k https://localhost:8443/api/v1/pods
# Kubernetes treats you as user "mahin" with group "dev-team"

Try restricted:
curl -k https://localhost:8443/api/v1/namespaces/kube-system/pods
────────────────────────
```

```
E) VERIFY DIRECT ACCESS DOESN’T WORK

Direct spoof header should fail:
curl -k -H "X-Remote-User=hacker" https://<API-SERVER>:6443/api

Expected:
Unauthorized
────────────────────────
```

```
F) SECURITY CHECKLIST

* Proxy MUST terminate TLS
* Proxy should authenticate clients (ideally mTLS)
* `--requestheader-client-ca-file` ensures proxy identity
* Do NOT expose proxy to public internet
* Never forward internet traffic straight to API server
────────────────────────
```

```
DONE — Proxy Authentication works end-to-end.
```

Want next?
Envoy | Traefik | Istio | JWT → X-Remote-* mapping examples 😎


---


Here is the **full practical** for creating all three files
`front-proxy-ca.crt`, `front-proxy-client.crt`, `front-proxy-client.key`
(works anywhere — Ubuntu, RHEL, CentOS, Alpine).

```
────────────────────────
A) CREATE FRONT-PROXY CA
────────────────────────
```

**1️⃣ Generate CA private key**

```
openssl genrsa -out front-proxy-ca.key 2048
```

**2️⃣ Create CA certificate**

```
openssl req -x509 -new -nodes \
  -key front-proxy-ca.key \
  -subj "/CN=front-proxy-ca" \
  -days 3650 \
  -out front-proxy-ca.crt
```

This CA will be trusted by kube-apiserver to validate proxy client certs.

```
FILES CREATED:
front-proxy-ca.key   (KEEP SECRET)
front-proxy-ca.crt   (SHARED WITH kube-apiserver)
```

```
────────────────────────
B) CREATE FRONT-PROXY CLIENT CERT
────────────────────────
```

**3️⃣ Create client private key**

```
openssl genrsa -out front-proxy-client.key 2048
```

**4️⃣ Create CSR (Certificate Signing Request)**

```
openssl req -new \
  -key front-proxy-client.key \
  -subj "/CN=front-proxy-client" \
  -out front-proxy-client.csr
```

**5️⃣ Sign CSR with the CA**

```
openssl x509 -req \
  -in front-proxy-client.csr \
  -CA front-proxy-ca.crt \
  -CAkey front-proxy-ca.key \
  -CAcreateserial \
  -out front-proxy-client.crt \
  -days 3650 \
  -sha256
```

```
FILES CREATED:
front-proxy-client.key   (proxy identity key)
front-proxy-client.crt   (certificate trusted by API server)
front-proxy-client.srl   (serial track file)
```

```
────────────────────────
C) FILE PERMISSIONS (IMPORTANT)
────────────────────────
```

```
chmod 600 front-proxy-client.key
chmod 644 front-proxy-client.crt
chmod 644 front-proxy-ca.crt
```

```
────────────────────────
D) COPY THEM TO THE API SERVER
────────────────────────
```

```
sudo cp front-proxy-ca.crt /etc/kubernetes/pki/
sudo cp front-proxy-client.crt /etc/kubernetes/pki/
sudo cp front-proxy-client.key /etc/kubernetes/pki/
```

*(If kubeadm cluster already generated them — skip this step)*

Restart happens automatically because kube-apiserver is static pod.

Verify:

```
kubectl get pods -n kube-system | grep apiserver
```

```
────────────────────────
E) TEST CERT WORKS
────────────────────────
```

Try reaching API server directly with certs:

```
curl --cert front-proxy-client.crt \
     --key front-proxy-client.key \
     --cacert front-proxy-ca.crt \
     https://<API-IP>:6443/api
```

If it responds → cert chain is valid.

```
────────────────────────
DONE — you now have:
front-proxy-ca.crt       (trusted by API)
front-proxy-client.crt   (proxy identity cert)
front-proxy-client.key   (proxy private key)
────────────────────────
```

Want next?
• Automate this with a script
• Replace NGINX with Envoy + mTLS
• Rotate these certificates safely
