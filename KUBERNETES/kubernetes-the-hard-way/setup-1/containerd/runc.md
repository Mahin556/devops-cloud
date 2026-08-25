Yes. This section is demonstrating the **lowest-level way to run a container with `runc`**, without Docker or containerd managing the container for you.

I'll explain the theory first, then the commands and the complete flow.

---

# 1. What is `runc`?

`runc` is a **low-level OCI-compliant container runtime**.

Its primary responsibility is:

> Take an OCI runtime bundle and create/run the Linux container from it.

It uses Linux kernel features such as:

* Namespaces
* cgroups
* capabilities
* seccomp
* filesystem isolation
* mount namespaces
* process isolation

The important distinction is:

```text
Docker
   ↓
containerd
   ↓
runc
   ↓
Linux kernel
   ↓
Container
```

But `runc` itself can be used directly:

```text
runc
  ↓
Linux kernel
  ↓
Container
```

---

# 2. `runc` vs `containerd`

This is extremely important for interviews.

### `runc`

`runc` is responsible for **actually creating and starting the container process**.

It is a low-level runtime.

### `containerd`

`containerd` is a higher-level container runtime/daemon.

It handles things such as:

* Image pulling
* Image management
* Container lifecycle
* Snapshotters
* Runtime management
* Networking integration
* Container metadata
* CRI integration for Kubernetes

Then containerd delegates the actual low-level container creation to a runtime such as `runc`.

Conceptually:

```text
                    containerd
                        |
          +-------------+-------------+
          |             |             |
       Images       Containers    Snapshots
                        |
                        ↓
                 containerd-shim
                        |
                        ↓
                      runc
                        |
                        ↓
                  Linux kernel
```

---

# 3. What is OCI?

OCI = **Open Container Initiative**.

OCI defines standards for containers.

Two important specifications are:

### OCI Image Specification

Defines how a container image is structured.

For example:

```text
Image
 ├── Manifest
 ├── Config
 └── Layers
```

### OCI Runtime Specification

Defines how a container should be executed.

It describes things such as:

* Process
* Arguments
* Environment variables
* Root filesystem
* Mounts
* Namespaces
* Capabilities
* cgroups
* Security settings

The `runc` runtime follows the OCI Runtime Specification.

---

# 4. What is an OCI bundle?

This is the most important concept in this example.

`runc` doesn't simply take an image name like:

```bash
runc run alpine
```

Instead, traditionally it expects an **OCI runtime bundle**.

A bundle contains:

```text
bundle/
├── config.json
└── rootfs/
```

For example:

```text
alpine/
├── config.json
└── rootfs/
    ├── bin/
    ├── dev/
    ├── etc/
    ├── home/
    ├── lib/
    ├── proc/
    ├── root/
    ├── sys/
    ├── tmp/
    ├── usr/
    └── var/
```

There are two important components:

### `config.json`

Describes **how the container should run**.

### `rootfs`

Contains the **filesystem that the container sees as `/`**.

---

# 5. Creating the root filesystem

The example creates a directory:

```bash
mkdir -p alpine/rootfs
```

This creates:

```text
alpine/
└── rootfs/
```

Then:

```bash
cd alpine
```

Now you're inside the OCI bundle directory.

---

# 6. Getting the Alpine root filesystem

The example uses Docker temporarily:

```bash
docker run -d alpine
```

This starts an Alpine container.

Then:

```bash
docker export $(docker run -d alpine) | tar -C rootfs -xv
```

Let's break that down.

### Step 1

```bash
docker run -d alpine
```

Docker starts an Alpine container in detached mode.

It returns a container ID.

For example:

```text
abc123456789
```

### Step 2

```bash
docker export abc123456789
```

`docker export` exports the container's filesystem as a tar archive.

Conceptually:

```text
Alpine container
      |
      ↓
docker export
      |
      ↓
tar archive
```

### Step 3

```bash
tar -C rootfs -xv
```

Extracts that archive into:

```text
rootfs/
```

So eventually you have:

```text
alpine/
└── rootfs/
    ├── bin
    ├── dev
    ├── etc
    ├── home
    ├── lib
    ├── proc
    ├── root
    ├── run
    ├── sbin
    ├── sys
    ├── tmp
    ├── usr
    └── var
```

This is now the container's root filesystem.

---

# 7. Why is it called `rootfs`?

Inside the container, this directory becomes `/`.

For example:

Host:

```text
/root/alpine/rootfs/
```

Inside container:

```text
/
```

So:

```text
Host                          Container

/root/alpine/rootfs/bin   →   /bin
/root/alpine/rootfs/etc   →   /etc
/root/alpine/rootfs/usr   →   /usr
/root/alpine/rootfs/tmp   →   /tmp
```

This is one of the fundamental concepts of containers.

---

# 8. Creating `config.json`

Now execute:

```bash
runc spec
```

This generates:

```text
config.json
```

So your bundle becomes:

```text
alpine/
├── config.json
└── rootfs/
```

`config.json` is the **OCI runtime configuration**.

It tells `runc` things like:

> What process should I start?

> What should the root filesystem be?

> What namespaces should the container have?

> What environment variables should exist?

> What capabilities should the process have?

> What mounts should be created?

---

# 9. Understanding `process`

The generated configuration contains:

```json
"process": {
    "terminal": true,
    "user": {
        "uid": 0,
        "gid": 0
    },
    "args": [
        "sh"
    ],
    "env": [
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "TERM=xterm"
    ],
    "cwd": "/"
}
```

Let's understand this.

---

## `terminal`

```json
"terminal": true
```

This tells runc that the process should have a terminal/TTY.

That's why you can interact with:

```text
/ #
```

after running:

```bash
runc run alpine-container
```

---

# 10. User UID/GID

```json
"user": {
    "uid": 0,
    "gid": 0
}
```

UID 0 = root.

GID 0 = root group.

Therefore, by default, the process runs as root inside this container.

You can verify:

```bash
id
```

You would typically see:

```text
uid=0(root) gid=0(root)
```

Important interview point:

> Container root is not necessarily equivalent to unrestricted host root because the container is isolated by namespaces, capabilities, seccomp, cgroups, and other security mechanisms.

---

# 11. `args`

```json
"args": [
    "sh"
]
```

This specifies the process to execute.

Therefore runc starts:

```bash
sh
```

inside the container.

That's why you get:

```text
/ #
```

If you changed it to:

```json
"args": [
    "sleep",
    "1000"
]
```

then the container would run:

```bash
sleep 1000
```

instead of giving you an interactive shell.

---

# 12. Environment variables

```json
"env": [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TERM=xterm"
]
```

These become environment variables inside the container.

For example:

```bash
echo $PATH
```

and:

```bash
echo $TERM
```

---

# 13. Working directory

```json
"cwd": "/"
```

This tells runc:

> Start the process with `/` as its current working directory.

That's why:

```bash
pwd
```

returns:

```text
/
```

---

# 14. `readonlyPaths`

The configuration also contains entries such as:

```json
"readonlyPaths": [
    "/proc/asound",
    "/proc/bus",
    "/proc/fs",
    "/proc/irq",
    "/proc/sys",
    "/proc/sysrq-trigger"
]
```

These paths are mounted/read-only to prevent the container process from modifying sensitive kernel-related interfaces.

This contributes to container isolation.

---

# 15. Running the container

Now you have:

```text
alpine/
├── config.json
└── rootfs/
```

Run:

```bash
runc run alpine-container
```

The syntax is:

```text
runc run <container-id>
```

Here:

```text
alpine-container
```

is simply the container ID/name assigned by you.

It must be unique among the containers managed by runc on that host.

---

# 16. What happens internally?

When you execute:

```bash
runc run alpine-container
```

roughly:

```text
runc
 |
 +-- reads config.json
 |
 +-- reads rootfs/
 |
 +-- creates namespaces
 |
 +-- configures mounts
 |
 +-- configures capabilities
 |
 +-- configures cgroups
 |
 +-- changes root filesystem
 |
 +-- starts "sh"
 |
 ↓
Container process
```

The Linux kernel provides the actual isolation mechanisms.

This is important:

> **runc doesn't virtualize a complete operating system. It uses Linux kernel primitives to isolate a normal Linux process.**

---

# 17. Where do namespaces come in?

Containers rely heavily on Linux namespaces.

For example:

```text
PID namespace
    ↓
Container sees its own processes

Mount namespace
    ↓
Container sees its own filesystem/mounts

Network namespace
    ↓
Container gets isolated network stack

UTS namespace
    ↓
Container can have its own hostname

IPC namespace
    ↓
Isolated IPC resources

User namespace
    ↓
Can provide UID/GID isolation
```

Conceptually:

```text
                 Linux Kernel
                      |
          +-----------+-----------+
          |           |           |
       runc       namespaces    cgroups
          |           |           |
          +-----------+-----------+
                      |
                      ↓
                  Container
```

---

# 18. Where do cgroups come in?

Namespaces provide **isolation**.

Cgroups provide **resource control/accounting**.

For example:

```text
Namespace
   ↓
"What can the container see?"

Cgroup
   ↓
"How much CPU/memory can the container use?"
```

For example, a container can be limited to:

```text
CPU    → 1 CPU
Memory → 512 MB
PIDs   → 100
```

This is why `Delegate=yes` in the containerd systemd unit we discussed earlier is important.

---

# 19. Why does `runc` need `config.json`?

Because runc is not an image manager.

It needs a runtime specification telling it how to execute the container.

Think of it like:

```text
Container image
       |
       | converted/extracted
       ↓
     rootfs
       +
  config.json
       |
       ↓
OCI bundle
       |
       ↓
     runc
       |
       ↓
   Container
```

---

# 20. Image vs rootfs vs container

This distinction is very important in interviews.

### Image

An image is a packaged application filesystem/configuration.

Example:

```text
alpine:latest
```

### Root filesystem

The extracted filesystem used by the container:

```text
rootfs/
├── bin/
├── etc/
├── usr/
└── var/
```

### OCI bundle

```text
bundle/
├── config.json
└── rootfs/
```

### Container

A running process created using that bundle.

So:

```text
Image
  ↓
Rootfs + config.json
  ↓
OCI bundle
  ↓
runc
  ↓
Running container
```

---

# 21. Why did the example use Docker?

This part can be confusing.

The purpose of the exercise is to demonstrate **runc directly**.

Docker was only used as a convenient way to obtain the Alpine filesystem:

```bash
docker run -d alpine
docker export ...
```

After obtaining the filesystem:

```text
Docker
  ↓
Alpine filesystem
  ↓
rootfs/
```

Docker is no longer required to start the example container.

Then:

```text
rootfs/
+
config.json
↓
runc
↓
container
```

So the actual container is being created by **runc**, not Docker.

---

# 22. Docker is no longer a monolith

This is the architectural evolution that your notes are trying to demonstrate.

Older Docker architecture was more tightly coupled.

Modern architecture separates responsibilities:

```text
Docker CLI
    |
    ↓
Docker Engine
    |
    ↓
containerd
    |
    ↓
containerd-shim
    |
    ↓
runc
    |
    ↓
Linux Kernel
```

This modular architecture means different components can be replaced independently.

---

# 23. Kubernetes architecture

Kubernetes can also use containerd without Docker Engine.

Modern Kubernetes:

```text
Kubernetes
     |
     ↓
   kubelet
     |
     | CRI
     ↓
 containerd
     |
     ↓
 containerd-shim
     |
     ↓
    runc
     |
     ↓
 Linux Kernel
     |
     ↓
 Container
```

This is why Kubernetes removed the old built-in Docker integration (`dockershim`) and moved toward CRI-compatible runtimes.

Also note:

**CRI-O and containerd are alternatives**, not that CRI-O runs "inside" containerd.

For example:

```text
Option 1:

kubelet
   ↓
containerd
   ↓
runc
```

or:

```text
Option 2:

kubelet
   ↓
CRI-O
   ↓
runc
```

Both can ultimately use an OCI runtime such as runc.

---

# 24. The complete picture

This is the key diagram to memorize:

```text
                    CONTAINER ECOSYSTEM

                         Kubernetes
                             |
                           kubelet
                             |
                            CRI
                             |
                    +--------+--------+
                    |                 |
               containerd           CRI-O
                    |                 |
                    |                 |
              containerd-shim        |
                    |                 |
                    +--------+--------+
                             |
                            runc
                             |
                  OCI Runtime Specification
                             |
                   +---------+---------+
                   |                   |
              Namespaces            cgroups
                   |                   |
                   +---------+---------+
                             |
                        Linux Kernel
                             |
                         Container
```

And the OCI bundle:

```text
OCI Bundle
│
├── config.json
│      │
│      ├── process
│      ├── args
│      ├── env
│      ├── cwd
│      ├── namespaces
│      ├── mounts
│      ├── capabilities
│      └── resource settings
│
└── rootfs/
       │
       ├── bin/
       ├── etc/
       ├── lib/
       ├── usr/
       ├── var/
       └── ...
```

### Interview-ready answer

**What is runc?**

> `runc` is a low-level OCI-compliant container runtime. It takes an OCI runtime bundle containing `config.json` and a root filesystem and uses Linux kernel features such as namespaces, cgroups, mounts, capabilities, and seccomp to create and start the container process. Containerd typically manages the higher-level container lifecycle and delegates the actual container execution to runc, commonly through containerd-shim.
