For **AWS Route 53**, the ExternalDNS configuration is simpler because you don't need to provide an API key/secret in the Deployment. The recommended approach is **IAM permissions + AWS IAM Roles for Service Accounts (IRSA)**.

Also, the Exoscale API credentials you pasted are sensitive—**rotate/revoke them immediately** if they are real credentials.

A typical Route 53 setup looks like this:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/external-dns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "pods"]
  verbs: ["get", "watch", "list"]

- apiGroups: ["extensions", "networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "watch", "list"]

- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: default
spec:
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.1
        args:
        - --source=service
        - --source=ingress
        - --provider=aws
        - --domain-filter=mahinraza.online
        - --policy=sync
```

### What changes from Exoscale?

Your Exoscale arguments:

```yaml
- --provider=exoscale
- --exoscale-apikey=...
- --exoscale-apisecret=...
- --exoscale-apienv=api
- --exoscale-apizone=de-fra-1
```

become simply:

```yaml
- --provider=aws
- --domain-filter=mahinraza.online
- --policy=sync
```

AWS authentication comes from the IAM role attached to the ServiceAccount:

```text
ExternalDNS Pod
      ↓
ServiceAccount
      ↓
IAM Role
      ↓
Route 53
      ↓
DNS records
```

The IAM role needs permissions such as:

```text
route53:ChangeResourceRecordSets
route53:ListResourceRecordSets
route53:ListHostedZones
```

If you're using **EKS**, IRSA or EKS Pod Identity can provide those credentials without putting AWS access keys in the YAML.
