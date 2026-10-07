If you want to **package a Helm chart and sign it with a GPG key named `demo`**, use:

```bash
helm package . --sign --key demo --keyring ~/.gnupg/secring.gpg
```

However, modern GPG versions usually use `~/.gnupg` key storage and Helm's `--keyring` option expects a **GPG keyring file**.

### 1. Check your GPG key

```bash
gpg --list-secret-keys --keyid-format LONG
```

You should see something like:

```text
sec   rsa4096/ABCDEF1234567890 2026-09-05 [SC]
      ...
uid           [ultimate] Demo <demo@example.com>
```

The key identifier can be used with Helm:

```bash
helm package . \
  --sign \
  --key "Demo" \
  --keyring ~/.gnupg/secring.gpg
```

### 2. If `secring.gpg` doesn't exist

With newer GPG versions, you may need to export the secret key into the legacy keyring format Helm expects:

```bash
gpg --export-secret-keys --armor "Demo" > /tmp/demo-secret.asc
```

Then import it into a temporary keyring:

```bash
mkdir -p /tmp/helm-gpg
chmod 700 /tmp/helm-gpg

gpg --homedir /tmp/helm-gpg --import /tmp/demo-secret.asc
```

Export the keyring:

```bash
gpg --homedir /tmp/helm-gpg \
    --export-secret-keys > /tmp/secring.gpg
```

Then:

```bash
helm package . \
  --sign \
  --key "Demo" \
  --keyring /tmp/secring.gpg
```
This generates:

```text
demo-0.1.0.tgz
demo-0.1.0.tgz.prov
```

The `.prov` file is the **Helm provenance/signature file**.

### Verify it

```bash
helm verify demo-0.1.0.tgz \
  --keyring /tmp/secring.gpg
```

If you're specifically following an older Helm tutorial that says **`--key demo`**, I can also show you the complete **GPG → Helm repo → `helm package --sign` → `helm verify`** setup end-to-end.
