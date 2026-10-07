You can generate a GPG key for Helm signing with `gpg`.

### 1. Generate the key

```bash
gpg --full-generate-key
```

You'll be prompted:

```text
Please select what kind of key you want:
   (1) RSA and RSA
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
   (9) ECC (sign and encrypt)
   (10) ECC (sign only)
```

For Helm chart signing, choose:

```text
4
```

Then:

```text
Keysize: 4096
```

Set an expiration if you want, for example:

```text
0 = key does not expire
```

Then provide:

```text
Real name: Demo
Email address: demo@example.com
Comment: Helm Chart Signing
```

Set a passphrase when prompted.

---

### 2. Check your key

```bash
gpg --list-secret-keys --keyid-format LONG
```

You'll get something similar to:

```text
sec   rsa4096/ABCDEF1234567890 2026-09-05 [SC]
      1234567890ABCDEF1234567890ABCDEF12345678
uid           [ultimate] Demo (Helm Chart Signing) <demo@example.com>
```

Your key can then be referred to as:

```text
Demo
```

or preferably by its key ID:

```text
ABCDEF1234567890
```

### 3. Export the public key

This is the key you can give to people/systems that need to **verify your Helm charts**:

```bash
gpg --armor --export ABCDEF1234567890 > demo-public-key.asc
```

You **do not** share your secret/private key.

---

### 4. Use it with Helm

The important part is:

```bash
helm package . --sign --key "Demo" --keyring ~/.gnupg/secring.gpg
```

If you're using a modern GPG version, `secring.gpg` may not exist, which is a common issue with Helm signing. I can show you the **modern GPG + Helm setup that works on Ubuntu** without getting stuck on the `secring.gpg` problem.
