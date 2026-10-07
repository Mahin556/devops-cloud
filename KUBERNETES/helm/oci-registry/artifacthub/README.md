## Publishing Helm Charts to Artifact Hub

Artifact Hub is a **discovery platform**, not a storage host. You push your chart to an OCI registry (GHCR, Docker Hub, etc.) and then link that registry to Artifact Hub.

### Push the Chart to an OCI Registry

Example with GitHub Container Registry (GHCR):

```bash
helm registry login ghcr.io -u your-github-username -p your-personal-access-token
helm package ./my-chart
helm push my-chart-1.0.0.tgz oci://ghcr.io/your-github-username
```

### (Optional) Add Artifact Hub Metadata

Create `artifacthub-repo.yml`:

```yaml
repositoryID: "your-unique-uuid-from-artifact-hub"
owners:
  - name: your-name
    email: your-email@example.com
```

Push it with ORAS using the special tag `artifacthub.io`:

```bash
oras push ghcr.io/your-github-username/my-chart:artifacthub.io \
  --config /dev/null:application/vnd.cncf.artifacthub.config.v1+yaml \
  artifacthub-repo.yml:application/vnd.cncf.artifacthub.repository-metadata.layer.v1.yaml
```

### Link the Registry to Artifact Hub

1. Sign in to [Artifact Hub](https://artifacthub.io/).
2. Go to **Control Panel → Add Repository**.
3. Fill in:
   - **Kind:** Helm charts
   - **Name:** my-chart-repo
   - **URL:** `oci://ghcr.io/your-github-username/my-chart`
4. Save. Artifact Hub will scan the registry for SemVer tags and index them.

### How Users Install from Artifact Hub

Once indexed, users can pull or install directly:

```bash
helm pull oci://ghcr.io/your-github-username/my-chart --version 1.0.0
helm install my-release oci://ghcr.io/your-github-username/my-chart --version 1.0.0
```