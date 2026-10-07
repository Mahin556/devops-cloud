If you're asking **why we need `--sign` when packaging a Helm chart**, it's for **authenticity and integrity**.

Normally:

```bash
helm package .
```

creates:

```text
demo-0.1.0.tgz
```

Anyone could potentially modify that `.tgz` after you publish it.

With signing:

```bash
helm package . --sign --key demo --keyring ...
```

Helm creates:

```text
demo-0.1.0.tgz
demo-0.1.0.tgz.prov
```

The `.prov` file contains the **cryptographic signature and chart metadata**.

When someone runs:

```bash
helm verify demo-0.1.0.tgz --keyring ...
```

Helm can verify:

1. **Integrity** — the chart wasn't modified after it was signed.
2. **Authenticity** — the chart was signed by the expected GPG key.
3. **Trust** — you can establish that the chart came from your trusted publisher.

### Simple example

Without signing:

```text
Developer
   │
   ▼
demo-0.1.0.tgz
   │
   ▼
Registry
   │
   ▼
User
```

Someone compromises the registry:

```text
demo-0.1.0.tgz
       ↓
   MODIFIED
       ↓
     User
```

With signing:

```text
Developer
   │
   │ GPG signs
   ▼
demo-0.1.0.tgz
demo-0.1.0.tgz.prov
   │
   ▼
Registry
   │
   ▼
User
   │
   │ helm verify
   ▼
✓ Signature valid
✓ Chart unchanged
```

So the **GPG key isn't needed just to create a Helm package**. It's needed when you want to establish a **verifiable chain of trust for the chart**.

For a private/company Helm repository, signing can be particularly useful when you want deployment systems to verify that charts haven't been tampered with.
