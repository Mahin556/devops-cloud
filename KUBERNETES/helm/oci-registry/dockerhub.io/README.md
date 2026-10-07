Docker Hub natively supports Helm charts by treating them as OCI (Open Container Initiative) artifacts. This allows you to use your existing Docker Hub namespaces and repositories to manage, store, and distribute Helm charts alongside your container images.

Because Docker Hub uses the standard OCI registry format (registry-1.docker.io), you can use native Helm CLI commands to package and upload your charts.

## Prerequisites

- **Helm 3.8+** for native OCI support. Since 3.8, the `HELM_EXPERIMENTAL_OCI=1` environment variable is no longer needed. Check your version:

  ```bash
  helm version
  ```

- **A Docker Hub account** with an access token (recommended over password).
- A chart directory containing a valid `Chart.yaml`.

---

## 1. Log in to Docker Hub

Docker Hub's OCI registry endpoint is `registry-1.docker.io` (note: **not** `docker.io` and **not** `index.docker.io` for OCI).

```bash
helm registry login registry-1.docker.io -u YOUR_DOCKER_USERNAME
```

You will be prompted for a password. Paste your **access token** (create one at https://hub.docker.com/settings/security) rather than your account password — tokens are revocable and scoped.

### For CI / non-interactive use

```bash
echo "$DOCKER_TOKEN" | helm registry login registry-1.docker.io \
  -u "$DOCKER_USERNAME" --password-stdin
```

### Where credentials are stored

Helm writes them to:

```
~/.config/helm/registry/config.json
```

You can override the location with `HELM_REGISTRY_CONFIG=/path/to/config.json`.

### Log out

```bash
helm registry logout registry-1.docker.io
```

---

## 2. Package the Chart

From the parent directory of your chart:

```bash
helm package ./your-chart-name
```

This produces `your-chart-name-<version>.tgz`, where `<version>` is the `version:` field in `Chart.yaml`.

If you want to pin the version explicitly:

```bash
helm package ./your-chart-name --version 0.1.0
```

Other useful flags:

| Flag | Purpose |
|---|---|
| `--app-version` | Sets the `appVersion` metadata in `Chart.yaml` |
| `--destination ./dist` | Writes the `.tgz` to a different directory |
| `--dependency-update` | Runs `helm dependency update` first |
| `--sign` | Signs the chart with a PGP key (requires `--key` and `--keyring`) |

Verify the archive contents:

```bash
tar -tzf your-chart-name-0.1.0.tgz | head
```

---

## 3. Push to Docker Hub

```bash
helm push your-chart-name-0.1.0.tgz oci://registry-1.docker.io/YOUR_DOCKER_USERNAME
```

### Important rules

- **The chart name in the OCI path must match the `name:` in `Chart.yaml`.** Helm validates this and will refuse the push if they differ. If your chart is named `myapp` in `Chart.yaml`, the URL must end in `.../YOUR_DOCKER_USERNAME/myapp`.
- **The version must match** the `version:` in `Chart.yaml`.
- The first push creates the repository on Docker Hub automatically.
- The repository is **private by default** on Docker Hub. To make it public, go to the repo's settings on hub.docker.com and flip the visibility.

After pushing, verify on Docker Hub: `https://hub.docker.com/r/YOUR_DOCKER_USERNAME/your-chart-name`.

### What actually gets uploaded

Helm pushes two OCI artifacts:

- A **config** blob containing the chart metadata.
- A **layer** blob containing the `.tgz` itself.

The manifest media type is `application/vnd.oci.image.manifest.v1+json`, with the config media type `application/vnd.cncf.helm.config.v1+json` and layer media type `application/vnd.cncf.helm.chart.content.v1.tar+gzip`. This is why Docker Hub can host Helm charts without any special-casing — they are just OCI artifacts.

---

## 4. Pull the Chart (Optional)

To download and inspect the chart locally:

```bash
helm pull oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
# Add --untar to extract immediately
helm pull oci://registry-1.docker.io/YOUR_USERNAME/my-chart --version 1.0.0 --untar
```

This writes `your-chart-name-0.1.0.tgz` to the current directory. Useful flags:

| Flag | Purpose |
|---|---|
| `--untar` | Extracts the `.tgz` into a directory instead of leaving it as a tarball |
| `--untardir ./charts` | Extracts into a specific directory |
| `--destination ./dist` | Writes the `.tgz` elsewhere |

Example with extraction:

```bash
helm pull oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name \
  --version 0.1.0 --untar --untardir ./local-charts
```

To inspect without downloading:

```bash
helm show chart oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
helm show values oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
helm show all oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
```

---

## 5. Install the Chart Directly

You do **not** need `helm repo add`. You can install straight from the OCI URL:

```bash
helm install my-release oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
```

With a values file:

```bash
helm install my-release oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name \
  --version 0.1.0 \
  -f values-prod.yaml \
  -n my-namespace --create-namespace
```

To render the manifests without installing:

```bash
helm template my-release oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.0
```

To upgrade an existing release from the same source:

```bash
helm upgrade my-release oci://registry-1.docker.io/YOUR_DOCKER_USERNAME/your-chart-name --version 0.1.1
```

---

## 6. Authentication for Private Charts

If the chart repository on Docker Hub is **private**, anyone pulling or installing must first log in:

```bash
helm registry login registry-1.docker.io -u YOUR_DOCKER_USERNAME --password-stdin
```

This applies to `helm pull`, `helm install`, `helm upgrade`, `helm template`, and `helm show` when the chart lives in a private repo.

For CI clusters (e.g., a Kubernetes cluster pulling via Flux or Argo CD), you need to supply registry credentials through the tooling:

- **Flux** uses an `OCIRepository` with a `secretRef` to a `kubernetes.io/dockerconfigjson` secret.
- **Argo CD** uses a repository credential template with `type: helm` and `enableOCI: "true"`.
- **kubelet pulling an image** is unrelated to Helm — Helm resolves and renders the chart client-side, and only the final manifests reach the cluster.

---

## 7. Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `Error: unexpected status from HEAD request ... 401 Unauthorized` | Not logged in, or token expired | `helm registry login registry-1.docker.io -u USER` |
| `Error: chart name "foo" does not match the name in the OCI reference "bar"` | OCI path name ≠ `Chart.yaml` name | Rename the last segment of the URL to match `Chart.yaml` |
| `Error: version "0.1.0" not found` | Pushed version differs from the one you're pulling | List tags on Docker Hub or push the correct version |
| `Error: cannot fetch ... 404 Not Found` | Wrong registry host (`docker.io` vs `registry-1.docker.io`) | Always use `registry-1.docker.io` for OCI |
| `Error: manifest unknown` | Chart was pushed but tagged differently, or repo is private and you're not logged in | Log in, then retry |
| `Error: push access denied` | Token lacks write scope | Create a token with read/write scope on Docker Hub |
| `Error: this feature has been disabled` | Very old Helm (< 3.8) | Upgrade Helm or set `HELM_EXPERIMENTAL_OCI=1` on 3.7 |

---

## 8. Versioning Strategy

The OCI tag is the chart `version`. To publish a new chart:

1. Bump `version:` in `Chart.yaml` (e.g., `0.1.0` → `0.1.1`).
2. Re-run `helm package ./your-chart-name`.
3. Re-run `helm push your-chart-name-0.1.1.tgz oci://registry-1.docker.io/YOUR_DOCKER_USERNAME`.

You cannot overwrite an existing tag; each version is immutable. Use semantic versioning for clarity.

Optionally, tag with `--app-version` to decouple the chart version from the application version:

```bash
helm package ./your-chart-name --version 0.2.0 --app-version 1.4.7
```

---

## 9. Full End-to-End Example

```bash
# Assume a chart directory ./myapp with Chart.yaml name: myapp, version: 0.1.0

# 1. Log in
echo "$DOCKER_TOKEN" | helm registry login registry-1.docker.io \
  -u "$DOCKER_USERNAME" --password-stdin

# 2. Package
helm package ./myapp
# -> myapp-0.1.0.tgz

# 3. Push
helm push myapp-0.1.0.tgz oci://registry-1.docker.io/$DOCKER_USERNAME
# -> Pushed: registry-1.docker.io/$DOCKER_USERNAME/myapp:0.1.0
# -> Digest: sha256:...

# 4. Verify by pulling
helm pull oci://registry-1.docker.io/$DOCKER_USERNAME/myapp --version 0.1.0

# 5. Install into a cluster
helm install myapp-release oci://registry-1.docker.io/$DOCKER_USERNAME/myapp \
  --version 0.1.0 -n apps --create-namespace

# 6. Inspect the release
helm list -n apps
kubectl get all -n apps
```

---

## 10. Why OCI Instead of a Traditional Chart Repo

| Aspect | Traditional `helm repo add` | OCI (Docker Hub, GHCR, etc.) |
|---|---|---|
| Hosting | Needs a chart repo server (`index.yaml`) | Any OCI registry |
| Index | `helm repo update` required | No index; version is the OCI tag |
| Auth | Repo-level credentials | Same as container registry |
| Signing | Provenance files | Cosign / Sigstore signatures |
| Tooling | `helm repo add`, `helm search repo` | `helm pull`, `helm install` from `oci://` |

OCI is now the recommended distribution mechanism because it reuses existing registry infrastructure, supports standard auth and signing, and removes the need for an `index.yaml` server.

---

## 11. Cleanup

```bash
helm uninstall myapp-release -n apps
helm registry logout registry-1.docker.io
```

To delete the chart from Docker Hub entirely, use the web UI or the Docker Hub API — Helm has no `helm push --delete` equivalent.