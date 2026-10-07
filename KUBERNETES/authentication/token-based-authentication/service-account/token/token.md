```bash
+--------------------------+-------------------------------+---------------------------------------+
| Flag / Command           | Purpose                       | Example                               |
+--------------------------+-------------------------------+---------------------------------------+
| create token <sa>        | Issue short-lived token       | kubectl create token demo-sa          |
| --namespace / -n         | Use SA in another namespace   | kubectl create token sa -n kube-system|
| --duration               | Set token lifetime            | kubectl create token sa --duration 1h |
| --audience               | Restrict token usage target   | kubectl create token sa --audience api|
| --audience (repeated)    | Multiple allowed audiences    | --audience api --audience metrics     |
| --bound-object-kind      | Bind token to resource type   | --bound-object-kind Pod               |
| --bound-object-name      | Bind token to specific object | --bound-object-name nginx             |
| --bound-object-uid       | Bind to exact UID             | --bound-object-uid 1234abcd...        |
| -o json/yaml             | Output structured format      | -o json                               |
| -o jsonpath              | Extract only token field      | -o jsonpath='{.status.token}'         |
+--------------------------+-------------------------------+---------------------------------------+
```

```bash
kubectl create token <sa>

kubectl create token <sa> --namespace <ns>

kubectl create token <sa> --duration 10m
kubectl create token <sa> --duration 1h
kubectl create token <sa> --duration 24h

kubectl create token <sa> --audience <aud>
kubectl create token <sa> --audience kube-api
kubectl create token <sa> --audience https://example.com
kubectl create token <sa> --audience api --audience metrics

kubectl create token <sa> --bound-object-kind Pod --bound-object-name <pod>
kubectl create token <sa> --bound-object-kind Pod --bound-object-name <pod> --bound-object-uid <uid>

kubectl create token <sa> --bound-object-kind Node --bound-object-name <node>
kubectl create token <sa> --bound-object-kind Node --bound-object-name <node> --bound-object-uid <uid>

kubectl create token <sa> --bound-object-kind Secret --bound-object-name <secret>
kubectl create token <sa> --bound-object-kind Secret --bound-object-name <secret> --bound-object-uid <uid>

kubectl create token <sa> -o json
kubectl create token <sa> -o yaml
kubectl create token <sa> -o name
kubectl create token <sa> -o jsonpath='{.status.token}'
kubectl create token <sa> -o go-template='{{ .status.token }}'

kubectl create token <sa> -o json --show-managed-fields=true

kubectl create token <sa> -n <ns> --duration 1h
kubectl create token <sa> --audience metrics --duration 30m
kubectl create token <sa> --bound-object-kind Pod --bound-object-name web --duration 10m
kubectl create token <sa> --audience api --bound-object-kind Pod --bound-object-name app --duration 1h -o json

kubectl create token <sa> \
  -n <ns> \
  --duration 2h \
  --audience api \
  --audience metrics \
  --bound-object-kind Pod \
  --bound-object-name app-xyz \
  --bound-object-uid 0123abcd \
  -o yaml
```
```bash
Kubernetes Service Account Token – --audience Comprehensive Guide

• Service account tokens are JWTs containing an "aud" claim (audience)
  → Audience defines who is allowed to trust and validate the token.

• Default audience
    https://kubernetes.default.svc.cluster.local
  Meaning: token works only against the Kubernetes API server unless specified otherwise.

Why audience matters
• Prevents stolen tokens being reused on other services.
• Restricts authentication scope to only intended systems.
• Enables workload-to-service auth beyond the Kubernetes API.

When to use --audience
• Workload calls something other than kube-apiserver:
  - Metrics server
  - Mutating/validating admission webhook
  - External API using Kubernetes JWKS
  - Cloud identity (AWS/GCP/Azure), Vault, secret stores, etc.

Usage Examples
• Default (Kubernetes API only):
    kubectl create token demo-sa

• Token for custom API:
    kubectl create token demo-sa --audience https://example.com

• Token for metrics server:
    kubectl create token demo-sa --audience metrics-server

• Token with multiple audiences:
    kubectl create token demo-sa \
      --audience api \
      --audience metrics
  Resulting claim:
    "aud": ["api","metrics"]

Audience mismatch behavior
• Token submitted to a service with a different expected audience
  → Authentication fails with:
    invalid audience
  Token is fine, but not for that system.

Who checks the audience
• Any system verifying the JWT signature:
  - Kubernetes API server
  - Admission webhooks
  - Services validating via cluster JWKS
  - Cloud or federated identity systems

Mental model
• duration  → how long token lives
• namespace → which SA it belongs to
• audience  → who can trust the token
• bound     → token dies when resource dies

Real-world example
• Token created for Vault:
    kubectl create token app --audience vault
• Vault trusts aud="vault" → accepted
• Kube API expects default audience → rejects
  → Perfect token isolation and safety.

TL;DR
Use --audience to restrict tokens so they are valid only for specific services.
This dramatically limits risk if a token leaks.
```