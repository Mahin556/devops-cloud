`kubectl get --raw` lets you **directly query the Kubernetes API Server using an HTTP API path**, without using the normal `kubectl get pods`, `kubectl get deployments`, etc. commands.

```text
kubectl
  │
  └── get --raw "/API-PATH"
             │
             ▼
       Kubernetes API Server
```

#### Check Kubernetes API root

```bash
kubectl get --raw /
```
```json
{
  "paths": [
    "/api",
    "/apis",
    "/healthz",
    "/version",
    "/openapi",
    "/openapi/v2",
    "/openapi/v3"
  ]
}
```

#### Kubernetes version
```bash
kubectl get --raw /version
```
```json
{
  "major": "1",
  "minor": "31",
  "gitVersion": "v1.31.0",
  "gitCommit": "...",
  "platform": "linux/amd64"
}
```
This is roughly equivalent to:
```bash
kubectl version
```

#### API health
```bash
kubectl get --raw /healthz
```
```bash
kubectl get --raw /readyz
```
```bash
kubectl get --raw /livez
```
```text
ok
```

#### List API versions

##### Core API
```bash
kubectl get --raw /api
```
```json
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ]
}
```

##### Other API groups
```bash
kubectl get --raw /apis
```
```text
apps
batch
autoscaling
networking.k8s.io
storage.k8s.io
rbac.authorization.k8s.io
...
```

##### Get Pods directly through API

The Kubernetes API path for Pods is:
```text
/api/v1/namespaces/<namespace>/pods
```
For the `default` namespace:
```bash
kubectl get --raw /api/v1/namespaces/default/pods
```
This returns the actual API response:
```json
{
  "kind": "PodList",
  "apiVersion": "v1",
  "items": [
    {
      "metadata": {
        "name": "nginx"
      },
      "spec": {
        "containers": [...]
      }
    }
  ]
}
```
Compare:
```bash
kubectl get pods
```
with:
```bash
kubectl get --raw /api/v1/namespaces/default/pods
```
The second one is much closer to talking directly to the API server.

##### Get a specific Pod
```bash
kubectl get --raw /api/v1/namespaces/default/pods/nginx

kubectl get --raw /api/v1/namespaces/default/pods \
  --server https://localhost:64418 \
  --client-key adam.key \
  --client-certificate adam.crt \
  --certificate-authority ca.crt
```
This retrieves:
```text
GET /api/v1/namespaces/default/pods/nginx
```

##### Get all Pods in the cluster
You can query all namespaces:
```bash
kubectl get --raw /api/v1/pods
```
This corresponds approximately to:
```bash
kubectl get pods -A
```

##### Deployments
Deployments belong to the `apps/v1` API group.
API path:
```text
/apis/apps/v1
```
List Deployments:
```bash
kubectl get --raw /apis/apps/v1/namespaces/default/deployments
```
Specific Deployment:
```bash
kubectl get --raw /apis/apps/v1/namespaces/default/deployments/nginx
```

##### Services
Services are part of the core `v1` API.
```bash
kubectl get --raw /api/v1/namespaces/default/services
```
Specific Service:
```bash
kubectl get --raw /api/v1/namespaces/default/services/nginx
```

##### Nodes
Nodes are cluster-scoped:
```bash
kubectl get --raw /api/v1/nodes
```
Specific node:
```bash
kubectl get --raw /api/v1/nodes/node1
```
Notice there is **no namespace**.

##### Namespaces
```bash
kubectl get --raw /api/v1/namespaces
```
Specific namespace:
```bash
kubectl get --raw /api/v1/namespaces/default
```

##### CRDs
CRDs belong to:
```text
apiextensions.k8s.io/v1
```
List CRDs:
```bash
kubectl get --raw /apis/apiextensions.k8s.io/v1/customresourcedefinitions
```
Specific CRD:
```bash
kubectl get --raw /apis/apiextensions.k8s.io/v1/customresourcedefinitions/databases.example.com
```

##### OpenAPI schema
This is particularly relevant to your previous question.
###### OpenAPI v2
```bash
kubectl get --raw /openapi/v2
```
You can save it:
```bash
kubectl get --raw /openapi/v2 > openapi.json
```
###### OpenAPI v3
```bash
kubectl get --raw /openapi/v3
```
The v3 endpoint provides information about the available OpenAPI documents.

##### Metrics API
If Metrics Server is installed:
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```
For Pods:
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/default/pods
```
This is roughly the API behind:
```bash
kubectl top nodes
```
and:
```bash
kubectl top pods
```

##### API discovery
You can discover resources supported by an API group.
For example:
```bash
kubectl get --raw /api/v1
```
And:
```bash
kubectl get --raw /apis/apps/v1
```
The response describes the resources available in that API version.

##### Pretty-print JSON
`--raw` returns JSON, so combining it with `jq` is very useful:
```bash
kubectl get --raw /api/v1/namespaces/default/pods | jq
```
Get only Pod names:
```bash
kubectl get --raw /api/v1/namespaces/default/pods \
  | jq -r '.items[].metadata.name'
```
Output:
```text
nginx
redis
backend
```
Get container images:
```bash
kubectl get --raw /api/v1/namespaces/default/pods \
  | jq -r '.items[].spec.containers[].image'
```

##### The important difference: `/api` vs `/apis`
This is worth remembering.
###### Core Kubernetes APIs
```text
/api/v1
```
Examples:
```text
Pod
Service
Node
Namespace
ConfigMap
Secret
```
So:
```bash
kubectl get --raw /api/v1/pods
```

###### Named API groups
```text
/apis/<group>/<version>
```
Examples:
```text
/apis/apps/v1
/apis/batch/v1
/apis/networking.k8s.io/v1
/apis/rbac.authorization.k8s.io/v1
```
So:
```bash
kubectl get --raw /apis/apps/v1/namespaces/default/deployments
```

#### 18. How `kubectl get --raw` relates to `curl`
You can think of:
```bash
kubectl get --raw /api/v1/nodes
```
as approximately:
```bash
curl https://KUBE-APISERVER/api/v1/nodes
```
But `kubectl` handles **authentication, certificates, context, and credentials** from your kubeconfig.
So you normally don't have to manually provide:
```text
Bearer token
CA certificate
client certificate
```
