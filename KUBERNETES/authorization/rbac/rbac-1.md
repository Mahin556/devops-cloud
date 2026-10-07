### References:
- https://octopus.com/blog/k8s-rbac-roles-and-bindings
- https://spacelift.io/blog/kubernetes-rbac
- https://medium.com/@Ibraheemcisse/mastering-kubernetes-rbac-your-complete-guide-to-authentication-and-authorization-79c3633eb48f
- https://adityasamant.medium.com/users-groups-roles-and-api-access-in-kubernetes-10216cfab335
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://faun.pub/give-users-and-groups-access-to-kubernetes-cluster-using-rbac-b614b6c0b383
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://freedium-mirror.cfd/https://harsh05.medium.com/kubernetes-service-accounts-simplifying-authentication-and-authorization-07d5c50d2e77

---

```bash

kubectl config view -o jsonpath='{.users[?(@.name=="minikube")].user.client-certificate}' #Check certificates of speicifc user

openssl x509 -in /Users/adityasamant/.minikube/profiles/minikube/client.crt -text -noout | grep Subject | grep -v "Public Key Info"

kubectl create clusterrole createpods --verb=create --resource=pods

kubectl create clusterrolebinding createpods --clusterrole=createpods --user=jane

kubectl auth can-i create pods --as=poweruser --as-group=example:masters
```


* **Verbs Table**

| Category                       | Verbs              | Meaning / Purpose                                    |
| ------------------------------ | ------------------ | ---------------------------------------------------- |
| **Read Operations**            | `get`              | Retrieve a single resource by name                   |
|                                | `list`             | List multiple resources                              |
|                                | `watch`            | Stream updates when the resource changes             |
| **Write Operations**           | `create`           | Create a new resource                                |
|                                | `update`           | Replace the entire object                            |
|                                | `patch`            | Modify fields of an object                           |
|                                | `delete`           | Delete a resource                                    |
| **Special / Privileged Verbs** | `deletecollection` | Delete multiple resources in one call                |
|                                | `impersonate`      | Act as another user/service account (very sensitive) |
|                                | `bind`             | Attach Roles/ClusterRoles to subjects                |
|                                | `escalate`         | Grant permissions higher than you currently have     |
| **Wildcard (Dangerous)**       | `*`                | Grants **all** verbs (highest risk)                  |


* Role give permission in specific namespace
```bash
kubectl create namespace development
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

* RoleBinding link a role to user,group,service account.
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-rolebinding
  namespace: development
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
```

* To give access to all resources on all namespaces

* Cluster Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

* Binding a ClusterRole to ClusterRoleBinding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer-binding
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl auth can-i list pods --namespace=development --as=alice

kubectl auth can-i delete pods --namespace=development --as=alice

kubectl get roles -n development

kubectl get clusterroles

kubectl get rolebindings -n development

kubectl get clusterrolebindings

kubectl delete role developer-role -n development

kubectl delete rolebinding developer-rolebinding -n development
```

```yaml
# Namespace Role + RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-manager
  namespace: development
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list","create","delete"]
#This role (pod-manager) allows the developer to get, list, create, and delete pods within the development namespace.

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-manager-binding
  namespace: development
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: rbac.authorization.k8s.io
#This role binding (pod-manager-binding) binds the pod-manager role to the developer user within the development namespace.

---

# ClusterRole + ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get","list"]
#This cluster role (node-viewer) allows the ops-team group to get and list nodes across the entire cluster.

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-viewer-binding
subjects:
- kind: Group
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-viewer
  apiGroup: rbac.authorization.k8s.io
#This cluster role binding (node-viewer-binding) binds the node-viewer cluster role to the ops-team group, allowing them to view nodes across the entire cluster.
```

```bash
#To create a new Kubernetes user (e.g., “anvesh”), follow these steps:
#1. Generate User Key + CSR:
openssl genrsa -out anvesh.pem 4096
openssl req -new -key anvesh.pem -out anvesh.csr -subj "/CN=anvesh"

#2. Create Kubernetes CSR:
BASE64=$(cat anvesh.csr | base64 | tr -d '\n')
  
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: anvesh
spec:
  request: $BASE64
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["digital signature","key encipherment","client auth"]
EOF

#3. Approve & Retrieve Certificate:
kubectl certificate approve anvesh
kubectl get csr/anvesh -o jsonpath='{.status.certificate}' | base64 -d > anvesh.crt

#4. Create User kubeconfig:
KCFG=~/.kube/config-anvesh

API_SERVER=<https_endpoint>

kubectl --kubeconfig=$KCFG config set-cluster preprod --server=$API_SERVER --insecure-skip-tls-verify=true

kubectl --kubeconfig=$KCFG config set-credentials anvesh --client-certificate=anvesh.crt --client-key=anvesh.pem --embed-certs=true

kubectl --kubeconfig=$KCFG config set-context default --cluster=preprod --user=anvesh

kubectl --kubeconfig=$KCFG config use-context default

#5. Give Namespace Permissions (Role + RoleBinding):
#Role:
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {namespace: kube-system, name: pod-reader}
rules: [{apiGroups:[""], resources:["pods"], verbs:["get","list"]}]

#RoleBinding:
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: anvesh-pod-reader, namespace: kube-system}
subjects: [{kind: User, name: anvesh}]
roleRef: {kind: Role, name: pod-reader, apiGroup: rbac.authorization.k8s.io}

kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml

#6. Test:
kubectl --kubeconfig ~/.kube/config-anvesh get pods -n kube-system

#7. Cluster-wide Access (ClusterRole + ClusterRoleBinding):
#ClusterRole:
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: pod-lister}
rules: [{apiGroups:[""], resources:["pods"], verbs:["get","list"]}]

#ClusterRoleBinding:
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: anvesh-pod-lister}
subjects: [{kind: User, name: anvesh}]
roleRef: {kind: ClusterRole, name: pod-lister, apiGroup: rbac.authorization.k8s.io}

kubectl apply -f clusterrole.yaml
kubectl apply -f clusterrolebinding.yaml

#Now “anvesh” can list pods namespace-wide or cluster-wide depending on the RBAC applied.
#Forbidden errors occur when no RBAC permissions are granted.
```

---
---

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-group-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["*"]
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-group-binding
  namespace: production
subjects:
- kind: Group
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-group-role
  apiGroup: rbac.authorization.k8s.io
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pv-sc-access
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["*"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["*"]
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pv-sc-binding
subjects:
- kind: User
  name: harry    #name is case sensitive            
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pv-sc-access
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl describe clusterrole pv-sc-access | grep -A20 PolicyRule
```

---
---

```bash
kubectl create namespace test
kubectl create namespace test2
kubectl create namespace test3
kubectl create namespace test4
```
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myaccount
  namespace: test
```
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: test
  name: testadmin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```
* A RoleBinding connects the Role to a subject (User/Group/ServiceAccount).
* This RoleBinding grants the service account `myaccount` the permissions defined in the Role.
* The service account *myaccount* can access **everything only in the test namespace**.  
* It cannot access anything in other namespaces, because a Role is namespace-scoped.

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: testadminbinding
  namespace: test
subjects:
- kind: ServiceAccount
  name: myaccount
  apiGroup: ""
roleRef:
  kind: Role
  name: testadmin
  apiGroup: ""
```
```bash
kubectl get roles -n test
kubectl get rolebindings -n test
kubectl auth can-i --as=system:serviceaccount:test:myaccount get pods -n test
```

---
* A RoleBinding is namespaced.
* Role and RoleBinding should be in same namespace.
* (Role,RoleBinding) or Service_account can be on different namespaces.
```yaml
subjects:
- kind: ServiceAccount
  name: myaccount
  namespace: test
```
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: test2
  name: testadmin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```
```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: testadminbinding
  namespace: test2
subjects:
- kind: ServiceAccount
  name: myaccount
  namespace: test    # <-- different namespace
roleRef:
  kind: Role
  name: testadmin
  apiGroup: ""
```
* The `subjects:` field can reference ServiceAccounts, Users, Groups in any namespace.
* So the RoleBinding grants permissions in namespace test2 to a ServiceAccount in namespace test.
* But RoleRef CANNOT reference a Role in another namespace.
* RoleRef must always reference a Role in the SAME namespace as the RoleBinding.

---
* A ClusterRole is cluster-wide (not tied to any namespace), but a RoleBinding is namespace-scoped.
* So when a ClusterRole is attached to a ServiceAccount via a RoleBinding, the permissions apply only in that RoleBinding's namespace.
* We create a `RoleBinding` in the `test3` namespace that gives our ServiceAccount (myaccount in namespace test) the permissions of the cluster-wide role cluster-admin.
  ```yaml
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
  ```
  ```yaml
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: cluster-admin
  rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  ```
  ```yaml
  kind: RoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: testadminbinding
    namespace: test3
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
    apiGroup: ""
  roleRef:
    kind: ClusterRole
    name: cluster-admin
    apiGroup: ""
  ```
* The service account now has the full cluster-admin capabilities, but only inside the test3 namespace:
  ```bash
  $ kubectl get rolebindings -n test3
  NAME               ROLE                        AGE
  testadminbinding   ClusterRole/cluster-admin   21m
  ```
* Even though the SA is bound to a ClusterRole, permissions do not extend to other namespaces.
  ```bash
  $ kubectl get roles -n test4
  Error from server (Forbidden): roles.rbac.authorization.k8s.io is forbidden: \
  User "system:serviceaccount:test:myaccount" cannot list resource "roles" \
  in API group "rbac.authorization.k8s.io" in the namespace "test4"
  ```
* A ClusterRole is cluster-scoped, but RoleBindings are namespace-scoped.
* You cannot bind a ClusterRole to multiple namespaces with one RoleBinding.
* You must create one RoleBinding per namespace and reference the same ClusterRole.
* Bind the ServiceAccount to this ClusterRole in dev, qa, prod namespace.
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: access-multi-ns
    namespace: dev
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
  roleRef:
    kind: ClusterRole
    name: multi-namespace-admin
    apiGroup: rbac.authorization.k8s.io

  ---

  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: access-multi-ns
    namespace: qa
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
  roleRef:
    kind: ClusterRole
    name: multi-namespace-admin
    apiGroup: rbac.authorization.k8s.io

  ---

  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: access-multi-ns
    namespace: prod
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
  roleRef:
    kind: ClusterRole
    name: multi-namespace-admin
    apiGroup: rbac.authorization.k8s.io
  ```
---
* A ClusterRole is not namespaced, and a ClusterRoleBinding is also not namespaced.
So when you bind a ClusterRole to a ServiceAccount using a ClusterRoleBinding:
  * The permissions apply across the entire cluster.
  * All namespaces become accessible.
  * Resource scope is cluster-wide.

  ```yaml
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: cluster-admin
  rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  ```
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: testadminclusterbinding
  subjects:
  - kind: ServiceAccount
    name: myaccount
    namespace: test
    apiGroup: ""
  roleRef:
    kind: ClusterRole
    name: cluster-admin
    apiGroup: rbac.authorization.k8s.io
  ```


---
---

* Check whether RBAC is enabled.
* RBAC is technically an optional Kubernetes feature, although it’s enabled by default in popular distributions. 
  ```bash
  kubectl api-versions | grep rbac
  ```
* To manually enable RBAC support, you must start the Kubernetes API server with the --authorization-mode=RBAC flag set:
  ```bash
  kube-apiserver --authorization-mode=RBAC
  ```
---
* Service Account Management in Kubernetes
* Service Accounts are identities used by pods and automation inside Kubernetes.
* They allow workloads to authenticate to the API server securely and perform only the actions they've been granted.
  ```bash
  #Create a Service Account
  kubectl create serviceaccount demo-user

  #Create an authorization token for your Service Account:
  TOKEN=$(kubectl create token demo-user)

  #Add serice account credentials into kubeconfig file
  kubectl config set-credentials demo-user --token=$TOKEN

  #Add a context that bind user account with the cluster
  kubectl config set-context demo-user-context --cluster=default --user=demo-user

  #Check current context
  kubectl config current-context

  #Switch contect
  kubectl config use-context demo-user-context

  #Without any kind of authorication using RBAC
  kubectl get pods
  #Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:demo-user" cannot list resource "pods" in API group "" in the namespace "default

  kubectl apply -f -<<EOF
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: demo-role
    namespace: default
  rules:
    - apiGroups:
        - ""
      resources:
        - pods
      verbs:
        - get
        - list
        - create
        - update
  EOF

  kubectl apply -f -<<EOF
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: demo-role-binding
    namespace: default
  roleRef: #Identifies the Role object that is being assigned.
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: demo-role
  subjects: #A list of one or more users or Service Accounts to assign the Role to.
  - namespace: default
    kind: ServiceAccount
    name: demo-user
    apiGroup: ""
  EOF

  kubectl config use-context demo-user-context

  kubectl get pods

  kubectl run nginx --image=nginx:latest

  kubectl get pods -n test3 --as=system:serviceaccount:test:myaccount
  ```
  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: app-service-account
    namespace: production
  automountServiceAccountToken: true
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    namespace: production
    name: app-role
  rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: app-role-binding
    namespace: production
  subjects:
  - kind: ServiceAccount
    name: app-service-account
    namespace: production
  roleRef:
    kind: Role
    name: app-role
    apiGroup: rbac.authorization.k8s.io
  ```
* Disable token auto-mounting unless needed
  * To prevent workloads from accidentally accessing API credentials:
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: non-api-app
    automountServiceAccountToken: false
    ```
* Pod-level override
  * Even if the SA has automount enabled, you can override per pod:
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: secure-pod
    spec:
      serviceAccountName: non-api-app
      automountServiceAccountToken: false  # Overrides SA defaults
      containers:
      - name: app
        image: myapp:latest
    ```
* Kubernetes 1.24+ uses ephemeral tokens, not secrets.
  * Generate a short-lived token:
    ```bash
    kubectl create token app-service-account -n production
    ```
  * This token is valid for 1 hour and ideal for CLI access.

* Create a long-lived token (legacy secret method)
  Use only if absolutely needed (CI systems, legacy components):
  ```yaml
  apiVersion: v1
  kind: Secret
  type: kubernetes.io/service-account-token
  metadata:
    name: app-service-account-token
    namespace: production
    annotations:
      kubernetes.io/service-account.name: app-service-account
  type: kubernetes.io/service-account-token
  ```

---

```bash
# Check your current identity and permissions
kubectl auth whoami
kubectl auth can-i <verb> <resource>
kubectl auth can-i --list --as=<user>

kubectl describe role <name> -n <namespace>
kubectl describe rolebinding <name> -n <namespace>
kubectl get roles,rolebindings,clusterroles,clusterrolebindings

kubectl get pods --dry-run=server -n ns
kubectl auth can-i create deployments --as=user -n ns -v=8

# Test current permissions
kubectl auth can-i create deployments
kubectl auth can-i get pods --all-namespaces
kubectl auth can-i '*' '*'

kubectl auth can-i create deployments --as=alice -n rbac-demo
kubectl auth can-i delete secrets --as=alice -n rbac-demo
kubectl auth can-i get nodes --as=alice
kubectl auth can-i get pv --as david

# Test monitoring permissions
kubectl auth can-i get pods --as=monitoring-user --all-namespaces
kubectl auth can-i list pods --as=system:serviceaccount:<namespace>:<serviceaccountname> -n <namespace>
kubectl auth can-i get secrets --as=monitoring-user
# List all permissions for a user
kubectl auth can-i --list --as=alice -n rbac-demo
```

---

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: rbac-demo
  name: developer
rules:
# Pod management
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "watch", "create", "delete"]
  #pods/log: Access to pod logs
  #pods/exec: Execute commands in pods
  #Missing update verb: Developers can't modify running pods directly
# Service management
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# ConfigMap and Secret read access
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
# Deployment management
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# Ingress management
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: rbac-demo
subjects:
# Add specific users
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: bob
  apiGroup: rbac.authorization.k8s.io
# Add group (if using external auth)
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-reader
rules:
# Read access to most resources
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Exclude secrets for security
- apiGroups: [""]
  resources: ["secrets"]
  verbs: []
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-reader-binding
subjects:
- kind: User
  name: monitoring-user
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: prometheus-server
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: monitoring-reader
  apiGroup: rbac.authorization.k8s.io
```

---

* Custom Resource Access in Kubernetes RBAC
* Kubernetes RBAC does not only control built-in Kubernetes resources (Pods, Services, ConfigMaps, etc.).
* It can also control Custom Resources (CRDs) created by extensions like:
* Istio
  * Argo CD
  * Prometheus Operator
  * Cert-Manager
  * Vault
  * Cilium
  * Knative
  * Any CRD installed by Helm charts
* To manage these custom resources, you must give RBAC permissions to their API groups, not the default Kubernetes API group.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-resource-manager
rules:
# Standard Kubernetes resources
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["*"]
# Custom resources (example: Istio)
- apiGroups: ["networking.istio.io"]
  resources: ["virtualservices", "destinationrules"]
  verbs: ["*"]
# Custom resources (example: Prometheus)
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors", "prometheusrules"]
  verbs: ["*"]
```

---

* Custom Resource API Groups & Their Meaning

| API Group               | Installed By            | Type of Resources (CRDs)                                             | Purpose / What They Configure                          | Notes                               |
| ----------------------- | ----------------------- | -------------------------------------------------------------------- | ------------------------------------------------------ | ----------------------------------- |
| `networking.istio.io`   | **Istio Service Mesh**  | `virtualservices`, `destinationrules`, `gateways`, `serviceentries`  | Traffic routing, retries, circuit breakers, mesh rules | **Not native** Kubernetes resources |
| `monitoring.coreos.com` | **Prometheus Operator** | `servicemonitors`, `prometheusrules`, `alertmanagers`, `podmonitors` | Metrics scraping, alert rules, Prometheus config       | Used heavily in monitoring stacks   |

* Why RBAC is Needed for Custom Resources (CRDs)

| Reason                                     | Explanation                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| CRDs behave like native Kubernetes objects | After installation, CRDs appear in the API server and must follow RBAC rules.    |
| Users/apps need permissions to manage CRDs | Without roles, any request to CRDs returns **Forbidden**.                        |
| Ensures secure access                      | Prevents unauthorized manipulation of service mesh or monitoring configuration.  |
| Operators depend on RBAC                   | Istio, Prometheus Operator, etc., stop working if they cannot access their CRDs. |


---

```yaml
#ReadOnly Role Template
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: []
```
```yaml
#Developer Role Template
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: NAMESPACE
  name: developer
rules:
- apiGroups: ["", "apps", "networking.k8s.io"]
  resources: ["pods", "services", "deployments", "ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
```
---

* Kubernetes RBAC Security Checklist

```bash
| Security Item                                | Status | Notes |
|----------------------------------------------|--------|-------|
| RBAC enabled in cluster                      | [ ]    | Ensure API server uses --authorization-mode=RBAC |
| No unnecessary cluster-admin bindings        | [ ]    | Remove broad ClusterRoleBindings unless required |
| Service accounts follow least privilege      | [ ]    | Grant namespace-scoped Roles whenever possible |
| Regular permission audits scheduled          | [ ]    | Use kubectl auth can-i + audit logs review |
| Audit logging configured                     | [ ]    | Enable API server audit policy and log backend |
| Roles documented with purpose                | [ ]    | Store role purpose/owners in annotations |
| Consistent naming conventions                | [ ]    | Example: team-name:role-name:env |
| Test environment mirrors production RBAC     | [ ]    | Ensure RBAC changes are validated before rollout |
```

```bash
kubectl get roles,rolebindings -A
kubectl get clusterroles,clusterrolebindings
# Debugging
kubectl describe role <name> -n <namespace>
kubectl auth can-i <verb> <resource> --as=<user> -v=8
# Testing
kubectl auth can-i create pods --as=system:serviceaccount:default:default
kubectl apply --dry-run=server -f <file>
```

---
* Principle of Least Privilege (PoLP)
* Grant only the exact permissions needed — nothing more.
* Good
```yaml
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```
* Bad
```yaml
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

---
* Regular Permission Audits
```bash
#!/bin/bash
echo "=== RBAC Audit Report ==="
echo "Date: $(date)"
echo ""

echo "=== ClusterRoleBindings with cluster-admin ==="
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'

echo ""
echo "=== Users with wildcard permissions ==="
kubectl get roles,clusterroles -A -o json | \
  jq -r '.items[] | select(.rules[]?.verbs[]? == "*") | .metadata.name'
```

---
* Document RBAC Objects
```bash
metadata:
  name: developers-staging-role
  annotations:
    rbac.example.com/created-by: "platform-team"
    rbac.example.com/created-date: "2024-01-15"
    rbac.example.com/purpose: "Allow developers to deploy in staging"
    rbac.example.com/review-date: "2024-07-15"
```
---
* Avoid Giving “default” Service Account Permissions
* BAD
```yaml
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
```
* GOOD
```yaml
subjects:
- kind: ServiceAccount
  name: monitoring-agent
  namespace: monitoring
```

---
---

```bash
kubectl -n kube-system create serviceaccount devops-cluster-admin
```
```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: devops-cluster-admin-secret
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: devops-cluster-admin
type: kubernetes.io/service-account-token
EOF
```
```bash
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: devops-cluster-admin
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
EOF
```
```bash
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: devops-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: devops-cluster-admin
subjects:
- kind: ServiceAccount
  name: devops-cluster-admin
  namespace: kube-system
EOF
```

---
---

```bash
kubectl create namespace webapps

kubectl apply -f -<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: webapps
EOF

kubectl apply -f -<<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: webapps
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
EOF

kubectl apply -f -<<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: webapps
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: webapps
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: debug
  namespace: webapps
spec:
  serviceAccountName: app-service-account
  containers:
  - name: kubectl
    image: bibinwilson/docker-kubectl:latest
    command: ["/bin/sh", "-c", "sleep 3600"]
EOF

kubectl exec -it debug -n webapps -- sh

#Allowed (because Role allows it):
kubectl get pods
kubectl get configmaps
kubectl get deployments

#Not allowed (outside of namespace):
kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden...
```



