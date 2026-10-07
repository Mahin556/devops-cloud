This chapter is about **verifying Kubernetes platform binaries**. The main idea is:

> **Don't blindly trust a Kubernetes binary just because it is present on the server. Verify that it came from the expected source and that the binary currently running is exactly the binary you intended to run.**

The chapter goes one step further than normal checksum verification: it verifies the **actual `kube-apiserver` binary running inside the Kubernetes container**. That is the most interesting part.

---

# Chapter 14 — Verify Platform Binaries

The chapter has two levels of verification:

```text
Level 1
Downloaded Kubernetes binary
        ↓
Compare SHA-512
        ↓
Official Kubernetes checksum

Level 2
Binary actually running in container
        ↓
Extract/access it through /proc
        ↓
Calculate SHA-512
        ↓
Compare with trusted binary
```

The course describes this as creating a **fingerprint** of a file using a hash and comparing that fingerprint with the value provided by the trusted original source.

---

# 1. Why do we verify binaries?

Imagine you download:

```text
kube-apiserver
```

from somewhere.

You expect:

```text
Official Kubernetes kube-apiserver
```

But how do you know the file wasn't modified?

For example:

```text
Official binary
      │
      │ download
      ▼
Your server
```

An attacker could theoretically modify the binary:

```text
Official binary
      │
      ▼
Modified binary
      │
      ▼
Your server
```

Therefore we need a way to determine:

> **Is this file exactly the same as the original file?**

That's where a cryptographic hash comes in.

---

# 2. What is a hash?

A hash is essentially a **fingerprint of a file**.

For example:

```text
kube-apiserver
      │
      ▼
SHA-512
      │
      ▼
abcdef123456789.....
```

If the file changes even slightly:

```text
kube-apiserver
      │
      │ one bit changed
      ▼
SHA-512
      │
      ▼
different-hash
```

So:

```text
Same file
   ↓
Same hash

Different file
   ↓
Different hash
```

This is exactly why hashes are useful for verifying downloads.

The course describes SHA and MD5 as one-way hashing algorithms and uses SHA-512 for the Kubernetes binary verification exercise.

---

# 3. Why SHA-512?

The chapter specifically uses:

```bash
sha512sum
```

For example:

```bash
sha512sum kubernetes-server-linux-amd64.tar.gz
```

You'll get something similar to:

```text
abc123...... kubernetes-server-linux-amd64.tar.gz
```

The important part is the long hexadecimal value.

---

# 4. Trusted hash vs generated hash

Suppose Kubernetes provides this official checksum:

```text
ABCDEF123456789...
```

You download:

```text
kubernetes-server-linux-amd64.tar.gz
```

Then calculate:

```bash
sha512sum kubernetes-server-linux-amd64.tar.gz
```

Suppose you get:

```text
ABCDEF123456789...
```

Now:

```text
Official SHA-512
       =
Your SHA-512
       ↓
      PASS
```

If instead:

```text
Official SHA-512
       ≠
Your SHA-512
       ↓
     FAIL
```

That means you **should not trust the downloaded file without investigating**.

---

# 5. First step: determine your Kubernetes version

The course first asks you to determine which Kubernetes version your cluster is running.

For example:

```bash
kubectl get nodes
```

You might see:

```text
NAME       STATUS   VERSION
cks-node   Ready    v1.22.2
```

The important point is:

> Download the binary corresponding to the version you're actually running.

In your screenshot, you have:

```text
Kubernetes v1.22.2
```

and the `kube-apiserver` image is also:

```text
k8s.gcr.io/kube-apiserver:v1.22.2
```

So you're verifying the **v1.22.2** binary.

---

# 6. Download the Kubernetes server binary

The Kubernetes server package contains several binaries.

After extraction, you get something like:

```text
kubernetes/
└── server/
    └── bin/
        ├── kube-apiserver
        ├── kube-controller-manager
        ├── kube-scheduler
        ├── kube-proxy
        ├── kubelet
        ├── kubectl
        └── ...
```

The chapter is particularly interested in:

```text
kube-apiserver
```

because that's the binary actually running as part of the control plane.

---

# 7. First verification: downloaded archive

After downloading:

```text
kubernetes-server-linux-amd64.tar.gz
```

calculate its SHA-512:

```bash
sha512sum kubernetes-server-linux-amd64.tar.gz
```

You then compare the result against the SHA-512 value provided by the official Kubernetes release source.

Conceptually:

```text
Official Kubernetes release
          │
          ├── File
          └── SHA-512
                │
                │ compare
                ▼
Your downloaded file
          │
          └── SHA-512
```

If they match:

```text
Official hash
     =
Local hash

     PASS
```

The course initially suggests visually comparing the values, but then demonstrates a more reliable command-line comparison.

---

# 8. Why not just visually compare the hash?

Because SHA-512 is **very long**.

You could do:

```text
ABC123.............XYZ
ABC123.............XYZ
```

and visually inspect it.

But that's error-prone.

Instead, put the values into a file:

```text
compare
```

For example:

```bash
cat compare
```

might show:

```text
ABC123...
ABC123...
```

Then:

```bash
sort compare | uniq
```

or the course's approach:

```bash
uniq
```

can be used to determine whether the lines differ, depending on how the comparison file is constructed.

### Important subtlety

`uniq` only removes **adjacent duplicate lines**. So for a robust comparison, sorting first is safer:

```bash
sort compare | uniq
```

Or even better for two files:

```bash
diff file1 file2
```

The course is demonstrating the underlying idea rather than teaching `uniq` as a cryptographic verification mechanism.

---

# 9. Now the interesting part

The course doesn't stop after verifying:

```text
Downloaded archive
       ↓
Official checksum
       ↓
PASS
```

Because there's another question:

> **Is the Kubernetes API server actually running the binary I just verified?**

This is a much deeper question.

You might have:

```text
Verified binary
      │
      ▼
kubernetes/server/bin/kube-apiserver
```

but Kubernetes might actually be running:

```text
Some other kube-apiserver
```

So we need to compare the **running binary itself**.

---

# 10. Where is kube-apiserver running?

In your screenshot:

```bash
kubectl -n kube-system get pod | grep api
```

gives something like:

```text
kube-apiserver-cks-controlplane
```

And:

```bash
kubectl -n kube-system get pod kube-apiserver-cks-controlplane \
-o yaml | grep image
```

shows:

```text
image: k8s.gcr.io/kube-apiserver:v1.22.2
```

So we know:

```text
Kubernetes control plane
        │
        ▼
kube-apiserver Pod
        │
        ▼
v1.22.2
```

---

# 11. Why can't you `kubectl exec` into kube-apiserver?

This is the part shown clearly in your screenshot.

You tried:

```bash
kubectl -n kube-system exec -it kube-apiserver-cks-controlplane -- sh
```

and got:

```text
executable file not found in $PATH
```

Then you tried:

```bash
kubectl -n kube-system exec -it kube-apiserver-cks-controlplane -- bash
```

and got essentially the same result.

### Why?

Because the Kubernetes control-plane container is extremely minimal.

It doesn't contain:

```text
/bin/sh
/bin/bash
```

The container mainly contains the actual Kubernetes binary and whatever is required to run it.

Conceptually:

```text
Normal container

/
├── bin/
│   ├── sh
│   └── bash
├── etc/
├── usr/
└── application
```

versus:

```text
kube-apiserver container

/
└── kube-apiserver
```

or a similarly minimal filesystem.

Therefore:

```bash
kubectl exec ... -- sh
```

doesn't work.

This is actually a good security property:

> **A minimal container has fewer tools available to an attacker after a compromise.**

The course makes the same observation: the Kubernetes component containers are very minimal and don't even include a shell.

---

# 12. But we still need access to the binary

So now we have a problem.

We want:

```text
kube-apiserver binary
```

inside the container.

But:

```bash
kubectl exec ... -- sh
```

doesn't work.

How do we get it?

The answer is:

# `/proc`

---

# 13. Find the kube-apiserver process

On the node, run:

```bash
ps aux | grep kube-apiserver
```

Your screenshot shows something like:

```text
root  1843 ... kube-apiserver ...
```

The important number is:

```text
1843
```

That's the **PID** of the running kube-apiserver process on the node.

So:

```text
kube-apiserver
      │
      ▼
PID = 1843
```

Your PID may be different.

**Never assume `1843` on another system.**

---

# 14. `/proc/<PID>/root`

This is the clever Linux technique used by the course.

Linux exposes process information through:

```text
/proc
```

Every process has a directory:

```text
/proc/<PID>
```

For example:

```text
/proc/1843
```

Inside it, you'll find:

```text
/proc/1843/root
```

The `root` entry represents the root filesystem visible to that process.

So:

```text
/proc/1843/root
        │
        ▼
root filesystem of kube-apiserver process
```

That's extremely useful.

---

# 15. Your screenshot shows exactly this

You ran:

```bash
find /proc/1843/root/ -type f -name kube-api*
```

and found:

```text
/proc/1843/root/usr/local/bin/kube-apiserver
```

This means:

```text
Host filesystem
      │
      ▼
/proc/1843/root/
      │
      ▼
Container's root filesystem
      │
      ▼
/usr/local/bin/kube-apiserver
```

This is how you access the binary without needing a shell inside the container.

---

# 16. Why does `/proc/PID/root` work?

This is an important Linux concept.

Suppose:

```text
Host
│
├── PID 100
├── PID 500
└── PID 1843 ← kube-apiserver
```

PID 1843 has its own filesystem view.

Linux exposes that through:

```text
/proc/1843/root
```

Therefore:

```bash
ls /proc/1843/root/
```

lets you see the filesystem from that process's root.

And:

```bash
ls /proc/1843/root/usr/local/bin/
```

lets you inspect files inside the container filesystem.

---

# 17. Now calculate the hash of the running binary

This is the key command conceptually:

```bash
sha512sum /proc/1843/root/usr/local/bin/kube-apiserver
```

Now you have:

```text
Hash #1
Downloaded trusted kube-apiserver
```

and:

```text
Hash #2
Actually running kube-apiserver
```

Compare them:

```text
Downloaded binary
        │
        ▼
    SHA-512
        │
        │
        ▼
      HASH A

Running binary
        │
        ▼
    SHA-512
        │
        │
        ▼
      HASH B
```

If:

```text
HASH A == HASH B
```

then the actual binary running in the container is identical to the downloaded binary.

---

# 18. This gives you a chain of trust

This is the most important concept from the chapter.

You aren't merely saying:

> "I downloaded Kubernetes."

You're establishing:

```text
Official Kubernetes release
          │
          │ official SHA-512
          ▼
Downloaded archive
          │
          │ extract
          ▼
Downloaded kube-apiserver
          │
          │ SHA-512
          ▼
Running kube-apiserver
```

If all hashes match:

```text
Official
   ↓
Downloaded
   ↓
Running

ALL MATCH
```

you have strong evidence that the running binary is exactly the expected binary.

---

# 19. Let's map this directly to your screenshot

Your screenshot shows:

### Step 1

```bash
tar zxf kubernetes-server-linux-amd64.tar.gz
```

You extract the Kubernetes server package.

### Step 2

```bash
kubectl -n kube-system get pod | grep api
```

You identify the API server pod.

### Step 3

```bash
kubectl -n kube-system get pod kube-apiserver-cks-controlplane -o yaml | grep image
```

You verify:

```text
kube-apiserver:v1.22.2
```

### Step 4

You tried:

```bash
kubectl exec ... -- sh
```

and:

```bash
kubectl exec ... -- bash
```

Both fail because the container doesn't have a shell.

### Step 5

You identify the process:

```bash
ps aux | grep kube-apiserver
```

and obtain:

```text
PID = 1843
```

### Step 6

You locate the binary:

```bash
find /proc/1843/root/ -type f -name kube-api*
```

Result:

```text
/proc/1843/root/usr/local/bin/kube-apiserver
```

### Step 7

Calculate its SHA-512:

```bash
sha512sum /proc/1843/root/usr/local/bin/kube-apiserver
```

### Step 8

Compare it with your trusted extracted binary:

```bash
sha512sum kubernetes/server/bin/kube-apiserver
```

If both are identical:

```text
PASS
```

---

# 20. One subtle but important point

There are actually **three different things** you're verifying.

### A. Version

```bash
kubectl get nodes
```

or inspect the API server image:

```text
v1.22.2
```

This answers:

> **Which version am I running?**

---

### B. Integrity of downloaded file

```bash
sha512sum kubernetes-server-linux-amd64.tar.gz
```

compared with the official checksum.

This answers:

> **Did I download an unmodified release?**

---

### C. Integrity of running binary

```bash
sha512sum /proc/<PID>/root/.../kube-apiserver
```

compared with the trusted binary.

This answers:

> **Is the binary actually running in the container the same binary I verified?**

These are different questions.

---

# 21. Why this is useful from a security perspective

Imagine an attacker somehow replaces:

```text
/usr/local/bin/kube-apiserver
```

inside the running environment.

The Kubernetes version might still appear to be:

```text
v1.22.2
```

but:

```text
Official kube-apiserver
        ≠
Modified kube-apiserver
```

The version alone wouldn't prove integrity.

But the hash would change:

```text
Expected:

ABC123...


Running:

XYZ987...
```

Therefore:

```text
Version check
    +
Hash verification
```

is much stronger than just checking the version.

---

# 22. Why a hash doesn't prove everything

One important security nuance that the chapter doesn't go deeply into:

A hash is useful **only when the expected hash comes from a trusted source**.

This is bad:

```text
Attacker
   │
   ├── malicious binary
   └── malicious checksum
```

If you download both from the attacker, they'll match.

You need:

```text
Trusted Kubernetes source
        │
        └── expected hash
               │
               ▼
          Your binary
```

That's why the source of the checksum matters.

---

# 23. SHA-512 vs MD5

You may encounter:

```bash
md5sum
sha256sum
sha512sum
```

Conceptually:

```text
MD5
 └── old / collision weaknesses

SHA-256
 └── commonly used

SHA-512
 └── stronger SHA-2 variant
```

For this chapter, remember:

```bash
sha512sum
```

because that's what the Kubernetes release verification exercise uses.

---

# 24. CKS perspective

The course says this binary-verification section may be somewhat outside the main CKS scope, but the instructor includes it because it's a useful security technique.

For CKS, I'd focus on understanding these commands/concepts:

```bash
kubectl get nodes
```

```bash
sha512sum <file>
```

```bash
ps aux | grep kube-apiserver
```

```bash
/proc/<PID>/root
```

and especially:

```bash
sha512sum /proc/<PID>/root/path/to/binary
```

You don't need to memorize the instructor's exact PID or exact file paths if your environment differs.

---

# 25. The most important Linux concept here

You were previously learning about Kubernetes internals, containerd, and the relationship between containers and processes.

This chapter connects those concepts beautifully:

```text
Kubernetes Pod
      │
      ▼
Container
      │
      ▼
Linux process
      │
      ▼
PID
      │
      ▼
/proc/<PID>
      │
      ▼
/proc/<PID>/root
      │
      ▼
Container filesystem
      │
      ▼
kube-apiserver binary
```

That's why `/proc` is so powerful.

A container is ultimately backed by **Linux processes and namespaces**. Even when the container has no shell, you can sometimes inspect its process/filesystem from the host through Linux interfaces.

---

# 26. One correction to the course's wording

The instructor says the container can be considered hardened because it doesn't contain a shell.

That's **generally a good security property**, but don't interpret it as:

> "No shell = secure container."

A minimal container reduces the attacker's available tooling, but container security also depends on:

```text
Non-root execution
+
Capabilities
+
Namespaces
+
Seccomp
+
AppArmor/SELinux
+
Read-only filesystem
+
Resource limits
+
Image security
+
Network restrictions
```

So it's **one security improvement**, not a complete security strategy.

---

# 27. Final mental model

Remember this:

```text
             VERIFY KUBERNETES BINARY
                       │
                       ▼
              Check K8s version
                       │
                       ▼
             Download official release
                       │
                       ▼
             Get official SHA-512
                       │
                       ▼
             sha512sum downloaded file
                       │
                       ▼
                 Hashes match?
                    /       \
                  YES        NO
                   │          │
                   ▼          ▼
                Continue    Investigate
                   │
                   ▼
           Extract server binaries
                   │
                   ▼
            kube-apiserver binary
                   │
                   ▼
       Find running kube-apiserver PID
                   │
                   ▼
             /proc/<PID>/root
                   │
                   ▼
        Find running kube-apiserver
                   │
                   ▼
               sha512sum
                   │
                   ▼
          Compare with trusted binary
                   │
             ┌─────┴─────┐
             ▼           ▼
           MATCH       MISMATCH
             │             │
             ▼             ▼
            PASS       Investigate
```

### The key takeaway

**The chapter isn't really about `sha512sum`.**

It's teaching you **binary integrity and chain of trust**:

> **Verify the release you downloaded → verify the binary → locate the binary actually running inside the container → hash that binary → prove that the running binary matches the trusted binary.**

And your screenshot demonstrates a particularly useful Kubernetes/Linux technique: **when `kubectl exec` cannot work because a minimal container has no shell, use the host's `/proc/<PID>/root` to inspect the process's filesystem.**
