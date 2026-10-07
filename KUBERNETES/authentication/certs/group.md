* Kubernetes **does NOT have a “Group” object** like `kubectl create group`.
* Groups are **not stored inside Kubernetes**.
* Groups come from **external authentication sources**:
  * X.509 certificate CN/O fields
  * OIDC provider (Keycloak, Dex, Auth0, Okta…)
  * Static token files
  * Keystone (OpenStack)
  * LDAP → via OIDC or webhook-auth

So Kubernetes **reads group info from the user’s authentication token/certificate**, but does not create groups itself.

---

# How to “Create” a Group (Correct Way)

## **Method A – Using Certificates (client certificates)**

Best for labs, admins, small clusters.

### **Steps**

* When generating a client certificate for a user, assign groups in the **Organization (O)** field.
* Example: Create a user `mahinder` in group `dev-team` and `qa-team`.

### **OpenSSL example**
```bash
openssl genrsa -out mahinder.key 2048
openssl req -new -key mahinder.key -out mahinder.csr -subj "/CN=mahinder/O=dev-team/O=qa-team"
```
* Get this CSR signed by the Kubernetes CA:
```bash
openssl x509 -req -in mahinder.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out mahinder.crt -days 365
```

### **Result**

* Kubernetes now sees:
  * User: `mahinder`
  * Groups: `dev-team`, `qa-team`

Kubernetes automatically understands group membership through cert fields.

---

## **Method B – Using OIDC / SSO provider (Recommended for production)**

* Configure OIDC with:

  * `--oidc-issuer-url`
  * `--oidc-client-id`
  * `--oidc-groups-claim`
* Token issued by IdP includes `"groups": ["dev-team", "qa-team"]`.

No group objects required — groups come from OIDC token.

---

# How to Associate a Role / ClusterRole With a Group

This is the easy part.

## **RoleBinding (namespace-specific permissions)**

```bash
kubectl create rolebinding dev-read \
  --role=read-only \
  --group=dev-team \
  --namespace=dev
```

Or YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-read
  namespace: dev
subjects:
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: read-only
  apiGroup: rbac.authorization.k8s.io
```

---

## **ClusterRoleBinding (cluster-wide permissions)**

If you want the whole group to have permissions **cluster-wide**:

```bash
kubectl create clusterrolebinding dev-admins \
  --clusterrole=cluster-admin \
  --group=dev-team
```

Or YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dev-admins
subjects:
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

---

# How to Verify the User Belongs to the Group

If using certificates:

```bash
kubectl get --raw /apis/authentication.k8s.io/v1/tokenreviews
```

Or simply run any command with `--v=6`:

```bash
kubectl --kubeconfig user-kubeconfig --v=6 get pods
```

You will see:

```bash
User: mahinder
Groups: ["dev-team" "qa-team"]
```

