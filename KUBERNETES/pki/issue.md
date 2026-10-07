The reason you're seeing the same certificate after a full delete and recreate is that cert-manager stores the actual X.509 certificate in a **Kubernetes Secret**, and deleting the `Certificate` resource **does not** automatically delete that Secret. When you recreate the `Certificate`, cert-manager finds the existing Secret, sees a valid certificate inside, and simply reuses it instead of issuing a new one.

---

## 🧠 Why This Happens

By default, cert-manager does **not** set an owner reference on the Secret it creates. This is controlled by the `--enable-certificate-owner-ref` flag on the cert-manager controller. The default value is `false`, meaning the Secret will **not** be garbage-collected when the `Certificate` is deleted.

The cert-manager documentation confirms this behavior:

> "If the Certificates get deleted and re-applied, but the Secrets remain in the cluster, the newly applied Certificates should be able to pick up the same Secrets and should not unnecessarily reissue the X.509 certs."

This is a deliberate design choice to prevent unnecessary certificate reissuance (and potential downtime) when only the `Certificate` manifest is reapplied. However, it also means that a naive "delete everything and recreate" approach won't give you a fresh certificate.

This is a long-standing known issue — the cert-manager project has had GitHub issues about deleting a `Certificate` not deleting its Secret since 2018.

---

## ✅ How to Force a New Certificate

You need to delete **both** the `Certificate` resource **and** the associated Secret.

### Step 1 — Identify the Secret name

The Secret name is defined in your `Certificate` manifest under `spec.secretName`. You can also find it with:

```bash
kubectl get certificate <cert-name> -n <namespace> -o jsonpath='{.spec.secretName}'
```

### Step 2 — Delete both the Certificate and the Secret

```bash
# Delete the Certificate resource
kubectl delete certificate <cert-name> -n <namespace>

# Delete the Secret that holds the actual X.509 certificate
kubectl delete secret <secret-name> -n <namespace>
```

### Step 3 — Recreate the Certificate

Apply your `Certificate` manifest again:

```bash
kubectl apply -f certificate.yaml
```

Because the Secret no longer exists, cert-manager will detect that the certificate is missing and issue a brand-new one.

---

## 🔍 Verifying the Certificate is Actually New

After recreating, check the certificate's serial number and validity dates:

```bash
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' \
  | base64 -d \
  | openssl x509 -noout -serial -dates -subject
```

You should see a **new serial number** and a **fresh `notBefore` date** (i.e., just now, not an hour ago).

---

## ⚙️ Permanent Fix: Enable Owner References

If you want cert-manager to automatically delete the Secret whenever the `Certificate` is deleted, enable the `--enable-certificate-owner-ref` flag on the cert-manager controller.

**If installed via Helm:**

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set global.leaderElection.namespace=cert-manager \
  --set extraArgs[0]=--enable-certificate-owner-ref=true
```

**If installed via static manifests:**

Edit the cert-manager controller Deployment and add the flag to the args:

```yaml
spec:
  template:
    spec:
      containers:
      - name: cert-manager
        args:
        - --enable-certificate-owner-ref=true
```

Once this flag is set to `true`, each Secret will have an owner reference to the `Certificate`, and when the `Certificate` is deleted, Kubernetes will automatically garbage-collect the Secret.

> ⚠️ **Warning:** Once enabled, deleting a `Certificate` will immediately delete the Secret, which can cause downtime for any workloads using that TLS certificate. Make sure your workloads can handle the Secret disappearing and reappearing.

---

## 🧪 Alternative: Use `cmctl renew`

cert-manager provides a CLI tool called `cmctl` that can trigger a renewal directly:

```bash
cmctl renew <cert-name> -n <namespace>
```

This forces cert-manager to issue a new certificate without you having to manually delete Secrets. It's the cleanest way to rotate a certificate on demand.

---

## 📋 Summary

| Action | Result |
|---|---|
| Delete `Certificate` only | Secret remains → cert-manager reuses it → **same certificate** |
| Delete `Certificate` + `Secret` | cert-manager issues a **new certificate** |
| Enable `--enable-certificate-owner-ref=true` | Deleting `Certificate` auto-deletes Secret → next recreate issues a new certificate |
| `cmctl renew <cert>` | Forces a **new certificate** without deleting anything |

The key takeaway: **the Secret is the source of truth for the certificate, not the Certificate resource.** If you want a genuinely new certificate, you must delete the Secret.