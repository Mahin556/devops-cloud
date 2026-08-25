Absolutely. Since you are learning **containerd and Kubernetes internals**, the most useful way to learn `ctr`, `crictl`, and `nerdctl` is to understand **what layer each tool talks to**, then learn the commands.

# `ctr` vs `crictl` vs `nerdctl`

The three tools may all show containers, but they are designed for different purposes:

| Tool      | Talks to       | Main purpose                       | Kubernetes-aware? | Docker-like? |
| --------- | -------------- | ---------------------------------- | ----------------- | ------------ |
| `ctr`     | containerd API | containerd debugging/admin         | ❌                 | ❌            |
| `crictl`  | CRI API        | Kubernetes runtime debugging       | ✅                 | ❌            |
| `nerdctl` | containerd API | User-friendly container management | ❌*                | ✅            |
| `kubectl` | Kubernetes API | Kubernetes management              | ✅                 | ❌            |

* `nerdctl` can inspect Kubernetes containers using the `k8s.io` containerd namespace, but it does **not use CRI**. ([GitHub][1])

---

# 1. First understand the architecture

In a Kubernetes node using containerd:

```text
                         Kubernetes
                              │
                              │ CRI
                              ▼
                         containerd
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
            ctr            nerdctl          crictl
             │                │                │
             │                │                │
             └──────► containerd ◄────────────┘
                                      │
                                      │ CRI
                                      ▼
                              containerd CRI plugin
```

But technically, `crictl` is different:

```text
crictl
   │
   │ CRI API
   ▼
containerd CRI plugin
   │
   ▼
containerd
```

Whereas:

```text
ctr
  │
  │ containerd API
  ▼
containerd
```

and:

```text
nerdctl
   │
   │ containerd API
   ▼
containerd
```

This distinction is **very important for interviews**.

`crictl` is specifically intended for CRI-compatible runtimes and Kubernetes-node debugging. ([Kubernetes][2])

---

# 2. `ctr`

`ctr` is the **native command-line client for containerd**.

Think:

> **"I want to directly troubleshoot containerd."**

It is primarily a debugging utility bundled with containerd, rather than a user-friendly Docker replacement. ([GitHub][1])

---

## Check containerd

```bash
ctr version
```

```bash
ctr plugins ls
```

Very useful:

```bash
ctr info
```

---

# 3. Containerd namespaces

This is one of the most important `ctr` concepts.

Containerd uses **namespaces** to separate resources such as:

```text
images
containers
tasks
```

For example:

```text
default
k8s.io
```

You can see namespaces with:

```bash
ctr namespaces ls
```

The namespace can be specified with:

```bash
ctr -n k8s.io ...
```

Containerd's documentation explicitly describes using `-n` to inspect resources in different namespaces. ([GitHub][3])

---

## Why `ctr images ls` may look empty

You run:

```bash
ctr images ls
```

and get:

```text
No images
```

But Kubernetes clearly has images.

Why?

You are probably looking at:

```text
default
```

while Kubernetes is using:

```text
k8s.io
```

Try:

```bash
ctr -n k8s.io images ls
```

This is a **very common Kubernetes/containerd troubleshooting question**.

---

# 4. `ctr` image commands

### List images

```bash
ctr images ls
```

Kubernetes:

```bash
ctr -n k8s.io images ls
```

### Pull image

```bash
ctr image pull docker.io/library/nginx:latest
```

### Inspect image

```bash
ctr image info docker.io/library/nginx:latest
```

### Remove image

```bash
ctr image rm docker.io/library/nginx:latest
```

### Export image

```bash
ctr image export nginx.tar docker.io/library/nginx:latest
```

### Import image

```bash
ctr image import nginx.tar
```

---

# 5. `ctr` containers vs tasks

This is another **very important concept**.

Containerd distinguishes between:

```text
Container
```

and:

```text
Task
```

Think of:

```text
Container = definition/metadata
Task      = running process
```

For example:

```bash
ctr containers ls
```

shows container objects.

But:

```bash
ctr tasks ls
```

shows running tasks.

You may have:

```text
Container
   nginx
     │
     ▼
Task
   nginx process
```

---

## Start a container with `ctr`

For example:

```bash
ctr image pull docker.io/library/alpine:latest
```

Create a container:

```bash
ctr container create docker.io/library/alpine:latest myalpine
```

Then start its task:

```bash
ctr task start -d myalpine
```

Check:

```bash
ctr containers ls
```

and:

```bash
ctr tasks ls
```

---

# 6. `ctr` is NOT Docker

Don't expect:

```bash
ctr run -p 8080:80 nginx
```

to behave like Docker.

`ctr` is intentionally low-level and is not designed to provide the same friendly experience as Docker. `nerdctl` exists partly to provide that Docker-compatible experience on top of containerd. ([GitHub][4])

---

# 7. `nerdctl`

Now think:

> **"I want Docker-like commands, but I want to use containerd directly."**

That's `nerdctl`.

The official project describes `nerdctl` as a **Docker-compatible CLI for containerd**. ([GitHub][4])

So if you're familiar with:

```bash
docker ps
docker run
docker images
docker exec
docker logs
docker build
docker compose
```

then `nerdctl` will feel very familiar.

---

# 8. Basic `nerdctl` commands

### Check version

```bash
nerdctl version
```

### List containers

```bash
nerdctl ps
```

All containers:

```bash
nerdctl ps -a
```

### Pull image

```bash
nerdctl pull nginx
```

### List images

```bash
nerdctl images
```

### Run container

```bash
nerdctl run -d --name nginx -p 8080:80 nginx
```

### Logs

```bash
nerdctl logs nginx
```

### Follow logs

```bash
nerdctl logs -f nginx
```

### Execute command

```bash
nerdctl exec -it nginx /bin/bash
```

### Stop

```bash
nerdctl stop nginx
```

### Remove

```bash
nerdctl rm nginx
```

These Docker-like container-management commands are part of nerdctl's documented command set. ([GitHub][5])

---

# 9. Build images with nerdctl

One major advantage over `ctr`:

```bash
nerdctl build -t myapp:1.0 .
```

This uses BuildKit for building images when configured appropriately. ([GitHub][4])

Then:

```bash
nerdctl images
```

and:

```bash
nerdctl run myapp:1.0
```

---

# 10. nerdctl Compose

You can also use:

```bash
nerdctl compose up -d
```

and:

```bash
nerdctl compose down
```

`nerdctl compose` is designed to be compatible with the Docker Compose model. ([GitHub][6])

So:

```text
Docker
   │
   └── docker compose

containerd
   │
   └── nerdctl compose
```

---

# 11. Kubernetes + nerdctl

This is especially useful for your Kubernetes learning.

Kubernetes containers normally live in the:

```text
k8s.io
```

containerd namespace.

Therefore:

```bash
nerdctl --namespace k8s.io ps -a
```

can show Kubernetes containers.

The nerdctl documentation specifically recommends the `k8s.io` namespace for inspecting local Kubernetes containers. ([GitHub][4])

You can also inspect images:

```bash
nerdctl --namespace k8s.io images
```

And logs:

```bash
nerdctl --namespace k8s.io logs <container>
```

---

# 12. `crictl`

Now we get to the most important tool for **Kubernetes node troubleshooting**.

Think:

> **"Kubernetes is having a container-runtime problem."**

Use:

```bash
crictl
```

`crictl` communicates through the **Container Runtime Interface (CRI)**. Kubernetes documents it specifically as a CLI for inspecting and debugging CRI-compatible container runtimes. ([Kubernetes][2])

---

# 13. Configure crictl

For containerd, you commonly configure:

```text
/etc/crictl.yaml
```

Example:

```yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
```

Then:

```bash
crictl info
```

If containerd is working correctly, you should receive runtime information.

You can alternatively specify endpoints with flags; the Kubernetes documentation supports configuring runtime/image endpoints this way. ([Kubernetes][2])

---

# 14. `crictl` container commands

### List running containers

```bash
crictl ps
```

### List all containers

```bash
crictl ps -a
```

### Container details

```bash
crictl inspect <container-id>
```

### Container logs

```bash
crictl logs <container-id>
```

### Execute command

```bash
crictl exec -it <container-id> sh
```

### Stop container

```bash
crictl stop <container-id>
```

### Remove container

```bash
crictl rm <container-id>
```

---

# 15. `crictl` Pod commands

This is where `crictl` becomes very useful for Kubernetes troubleshooting.

List Pods:

```bash
crictl pods
```

Get Pod information:

```bash
crictl inspectp <pod-id>
```

Remove Pod sandbox:

```bash
crictl stopp <pod-id>
```

```bash
crictl rmp <pod-id>
```

You can filter:

```bash
crictl pods --name nginx
```

---

# 16. `crictl` image commands

List images:

```bash
crictl images
```

Pull:

```bash
crictl pull nginx:latest
```

Inspect:

```bash
crictl inspecti nginx:latest
```

Remove:

```bash
crictl rmi nginx:latest
```

---

# 17. The most important difference

Suppose you have a Kubernetes Pod:

```text
nginx Pod
   │
   └── nginx container
```

You can investigate it using different tools.

### Kubernetes level

```bash
kubectl get pod nginx
```

You're asking:

> What does Kubernetes API know about this Pod?

---

### CRI level

```bash
crictl pods
crictl ps -a
```

You're asking:

> What does the container runtime expose through CRI?

---

### containerd level

```bash
ctr -n k8s.io containers ls
ctr -n k8s.io tasks ls
```

You're asking:

> What does containerd itself know about these containers/tasks?

---

### Docker-like containerd level

```bash
nerdctl --namespace k8s.io ps -a
```

You're asking:

> Show me containerd containers using a Docker-like CLI.

---

# 18. Same problem, different tools

Suppose:

```bash
kubectl get pods
```

shows:

```text
nginx   CrashLoopBackOff
```

You can investigate:

### Step 1 — Kubernetes

```bash
kubectl describe pod nginx
```

### Step 2 — CRI

Find the container:

```bash
crictl ps -a
```

Then:

```bash
crictl logs <container-id>
```

### Step 3 — containerd

```bash
ctr -n k8s.io containers ls
```

and:

```bash
ctr -n k8s.io tasks ls
```

### Step 4 — nerdctl

```bash
nerdctl --namespace k8s.io ps -a
```

Then:

```bash
nerdctl --namespace k8s.io logs <container-id>
```

This gives you progressively lower-level visibility.

---

# 19. Important: `crictl` does NOT use the containerd namespace

This is a common misunderstanding.

You don't normally do:

```bash
crictl -n k8s.io
```

because `crictl` doesn't communicate with containerd using the containerd namespace mechanism.

Instead:

```text
crictl
   │
   │ CRI
   ▼
containerd CRI plugin
```

Whereas:

```text
ctr -n k8s.io
        │
        │ containerd API
        ▼
containerd namespace
```

And:

```text
nerdctl --namespace k8s.io
             │
             ▼
         containerd
```

---

# 20. Practical comparison

### Pull an image

```text
ctr:
ctr image pull nginx

crictl:
crictl pull nginx

nerdctl:
nerdctl pull nginx
```

But they reach the runtime differently.

---

### List containers

```text
ctr:
ctr -n k8s.io containers ls

crictl:
crictl ps -a

nerdctl:
nerdctl --namespace k8s.io ps -a
```

---

### Logs

```text
ctr:
# low-level/containerd-oriented; not the preferred Kubernetes log tool

crictl:
crictl logs <container-id>

nerdctl:
nerdctl --namespace k8s.io logs <container-id>
```

---

### Run a container

`nerdctl`:

```bash
nerdctl run -d nginx
```

`ctr`:

```bash
ctr run -d docker.io/library/nginx:latest nginx
```

`crictl`:

```text
crictl
```

is **not intended to be a general-purpose `docker run` replacement**. It is a CRI debugging/client tool.

---

# 21. Very important interview question

### Q: Why does `ctr -n k8s.io images ls` show images but `crictl images` shows something different?

Because they access containerd differently.

```text
ctr
 │
 └── containerd API
       │
       └── k8s.io namespace
```

while:

```text
crictl
 │
 └── CRI API
       │
       └── containerd CRI plugin
```

The CRI plugin/containerd integration determines what CRI exposes.

---

# 22. Another important interview question

### Q: Which one should I use for Kubernetes troubleshooting?

**Prefer `crictl`.**

Why?

Because Kubernetes communicates with the runtime through **CRI**, so `crictl` exercises the same CRI interface used by Kubernetes.

For example:

```bash
crictl info
crictl pods
crictl ps -a
crictl inspect
crictl logs
```

The Kubernetes documentation specifically positions `crictl` for debugging Kubernetes nodes and CRI-compatible runtimes. ([Kubernetes][2])

---

# 23. Which one should I use for containerd debugging?

Use:

```bash
ctr
```

For example:

```bash
ctr plugins ls
ctr namespaces ls
ctr -n k8s.io images ls
ctr -n k8s.io containers ls
ctr -n k8s.io tasks ls
```

It's particularly useful when you're trying to understand:

```text
containerd
  ↓
namespace
  ↓
image
  ↓
container
  ↓
task
  ↓
shim
  ↓
runtime
```

---

# 24. Which one should I use like Docker?

Use:

```bash
nerdctl
```

For example:

```bash
nerdctl run -d --name web -p 8080:80 nginx
nerdctl ps
nerdctl logs web
nerdctl exec -it web sh
nerdctl stop web
```

Its goal is explicitly to provide a Docker-compatible CLI for containerd. ([GitHub][4])

---

# 25. The easiest way to memorize

Remember this:

```text
                 CONTAINERD
                     │
          ┌──────────┴──────────┐
          │                     │
       ctr                    nerdctl
          │                     │
   Low-level CLI         Docker-like CLI
          │                     │
          └──────────┬──────────┘
                     │
                 containerd
                     │
                     │
                  CRI Plugin
                     ▲
                     │
                  crictl
                     │
                Kubernetes
```

### One-line memory trick

> **`ctr` = containerd internals**
> **`crictl` = Kubernetes/CRI troubleshooting**
> **`nerdctl` = Docker-like containerd CLI**

---

# 26. Commands I recommend memorizing for your Kubernetes interviews

### `ctr`

```bash
ctr version
ctr plugins ls
ctr namespaces ls
ctr -n k8s.io images ls
ctr -n k8s.io containers ls
ctr -n k8s.io tasks ls
ctr image pull <image>
```

### `crictl`

```bash
crictl info
crictl pods
crictl ps
crictl ps -a
crictl images
crictl inspect <container-id>
crictl logs <container-id>
crictl exec -it <container-id> sh
crictl pull <image>
```

### `nerdctl`

```bash
nerdctl version
nerdctl ps
nerdctl ps -a
nerdctl images
nerdctl pull <image>
nerdctl run -d <image>
nerdctl logs <container>
nerdctl exec -it <container> sh
nerdctl stop <container>
nerdctl rm <container>
nerdctl build -t <image> .
nerdctl compose up -d
```

For Kubernetes:

```bash
nerdctl --namespace k8s.io ps -a
nerdctl --namespace k8s.io images
```

The `k8s.io` namespace usage for Kubernetes inspection is documented by nerdctl itself. ([GitHub][4])

### The troubleshooting hierarchy I'd use on your RHEL + containerd Kubernetes setup

```text
kubectl
   ↓
crictl
   ↓
ctr -n k8s.io
   ↓
containerd logs
   ↓
containerd-shim
   ↓
runc / alternative OCI runtime
   ↓
Linux kernel
```

This hierarchy is especially useful when diagnosing the kind of **CRI v1 / containerd / shim / runtime** problems you've been working through.

[1]: https://github.com/containerd/nerdctl/blob/main/docs/faq.md?utm_source=chatgpt.com "nerdctl/docs/faq.md at main · containerd/nerdctl · GitHub"
[2]: https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/?utm_source=chatgpt.com "Debugging Kubernetes nodes with crictl | Kubernetes"
[3]: https://github.com/containerd/containerd/blob/main/docs/namespaces.md?utm_source=chatgpt.com "containerd/docs/namespaces.md at main · containerd/containerd · GitHub"
[4]: https://github.com/containerd/nerdctl?utm_source=chatgpt.com "GitHub - containerd/nerdctl: contaiNERD CTL - Docker-compatible CLI for containerd, with support for Compose, Rootless, eStargz, OCIcrypt, IPFS, ... · GitHub"
[5]: https://github.com/containerd/nerdctl/blob/main/docs/command-reference.md?utm_source=chatgpt.com "nerdctl/docs/command-reference.md at main · containerd/nerdctl · GitHub"
[6]: https://github.com/containerd/nerdctl/blob/main/docs/compose.md?utm_source=chatgpt.com "nerdctl/docs/compose.md at main · containerd/nerdctl · GitHub"
