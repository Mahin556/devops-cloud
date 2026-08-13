Yes. The easiest way to understand this is to separate **container privileges** into two categories:

1. **Container-level privileges** — Kubernetes settings such as `privileged`, `hostNetwork`, `hostPID`, etc.
2. **Linux capabilities** — individual Linux privileges such as `CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, `CAP_CHOWN`, etc.

The second category is what you're asking about most: **Linux capabilities**.

---

# 1. What are Linux capabilities?

Normally Linux had a simple model:

```text
root (UID 0)  →  almost everything
normal user   →  limited permissions
```

Capabilities split some root privileges into smaller pieces:

```text
                  ROOT PRIVILEGES
                       │
       ┌───────────────┼────────────────┐
       ↓               ↓                ↓
   CAP_CHOWN       CAP_NET_ADMIN    CAP_SYS_TIME
   change owner    network admin    change time
```

So instead of giving a container:

```yaml
privileged: true
```

you can sometimes give it only:

```yaml
capabilities:
  add:
    - NET_ADMIN
```

That's **least privilege**.

---

# 2. Important: `privileged: true` vs capabilities

### Normal container

```yaml
securityContext:
  privileged: false
```

It receives a limited/default set of capabilities.

### Add one capability

```yaml
securityContext:
  capabilities:
    add:
      - NET_ADMIN
```

Now it gets additional network administration privileges.

### Privileged container

```yaml
securityContext:
  privileged: true
```

This is much broader.

Think:

```text
CAPABILITY APPROACH
────────────────────────────
Container
   ↓
CAP_NET_ADMIN
   ↓
Only specific additional privilege


PRIVILEGED APPROACH
────────────────────────────
Container
   ↓
Many/all important capabilities
   +
relaxed device/security restrictions
   ↓
Much closer to host-level access
```

**Don't use `privileged: true` when a specific capability is enough.**

---

# 3. Complete Linux capability list

The exact set can vary slightly by Linux/kernel version, but these are the capabilities you should know on modern Linux systems.

I'll explain them in simple language.

---

## CAP_CHOWN

### Meaning

Allows changing the owner/group of files.

Normally:

```bash
chown user file
```

requires appropriate privilege.

With:

```text
CAP_CHOWN
```

the process can change file ownership.

### Simple:

> **Change who owns a file.**

---

# 4. CAP_DAC_OVERRIDE

DAC = **Discretionary Access Control**.

This capability allows bypassing many normal Linux file permission checks.

For example:

```text
file:
-r-------- root root secret.txt
```

A process normally can't read it.

With:

```text
CAP_DAC_OVERRIDE
```

it can bypass many read/write/execute permission checks.

### Simple:

> **Ignore many normal file permissions.**

⚠️ Very powerful.

---

# 5. CAP_DAC_READ_SEARCH

Allows bypassing permission checks specifically for:

* reading files
* directory searching/traversal

### Simple:

> **Read files and enter directories despite many permission restrictions.**

Difference:

```text
CAP_DAC_OVERRIDE
    ↓
bypass broader file permission checks

CAP_DAC_READ_SEARCH
    ↓
specifically bypass read/search restrictions
```

---

# 6. CAP_FOWNER

Allows bypassing permission checks that normally require the process to be the file owner.

It also allows certain operations that normally require ownership.

### Simple:

> **Act like you're the owner of files for many permission checks.**

---

# 7. CAP_FSETID

Controls preservation of special file permission bits such as:

```text
setuid
setgid
```

when modifying files.

### Simple:

> **Preserve special file permission bits.**

Usually not something an ordinary application needs.

---

# 8. CAP_KILL

Allows sending signals to processes without requiring the normal ownership relationship.

For example:

```bash
kill -9 PID
```

### Simple:

> **Kill/control other processes with fewer permission restrictions.**

---

# 9. CAP_SETGID

Allows changing group identity.

For example:

```text
setgid()
```

### Simple:

> **Change your Linux group identity.**

---

# 10. CAP_SETUID

Allows changing user identity.

For example:

```text
setuid()
```

### Simple:

> **Change your Linux user identity.**

⚠️ Important security capability.

For example:

```text
normal user
    ↓
change UID
    ↓
potentially become another user
```

---

# 11. CAP_SETPCAP

Allows manipulating capabilities of processes in certain circumstances.

### Simple:

> **Change/manage Linux capabilities.**

This can be security-sensitive because capabilities determine what processes can do.

---

# 12. CAP_LINUX_IMMUTABLE

Allows changing special filesystem flags such as:

```text
immutable
append-only
```

### Simple:

> **Change special file protection flags.**

For example:

```text
file → immutable
```

---

# 13. CAP_NET_BIND_SERVICE

Allows binding to ports below `1024`.

Normally:

```text
ports 0-1023
```

are considered privileged ports.

For example:

```text
TCP 80
TCP 443
```

Without this capability, a non-root process may not be able to bind to them.

### Simple:

> **Use low-numbered ports like 80 and 443.**

This is a capability that applications may legitimately need.

Example:

```yaml
securityContext:
  capabilities:
    add:
      - NET_BIND_SERVICE
```

---

# 14. CAP_NET_BROADCAST

Allows network broadcasting/multicasting operations that require this capability.

### Simple:

> **Send certain network broadcast traffic.**

Rarely needed by normal applications.

---

# 15. CAP_NET_ADMIN

This is a **very powerful networking capability**.

It can allow operations such as:

* configure network interfaces
* change routing
* configure firewall-related networking
* manipulate network namespaces/interfaces
* configure traffic control
* modify certain network settings

For example:

```bash
ip link
ip route
ip addr
```

### Simple:

> **Control Linux networking.**

⚠️ Powerful.

Commonly relevant to:

* VPN software
* network plugins
* routing applications
* advanced networking
* some security/network tools

---

# 16. CAP_NET_RAW

Allows use of raw sockets.

This is commonly required for things like:

```text
ping
```

and certain packet/network tools.

### Simple:

> **Create/send raw network packets.**

For example:

```bash
ping 8.8.8.8
```

may require raw socket privileges depending on the implementation/configuration.

⚠️ Security-sensitive because raw packets can be crafted.

---

# 17. CAP_IPC_LOCK

Allows locking memory into RAM.

Normally Linux can move memory pages to swap.

This capability allows applications to prevent certain memory from being swapped.

Used by applications such as:

* databases
* high-performance applications
* security-sensitive processes

### Simple:

> **Keep important memory in RAM instead of allowing it to be swapped.**

---

# 18. CAP_IPC_OWNER

Allows bypassing certain IPC permission checks.

IPC = Inter-Process Communication.

Examples include:

```text
shared memory
semaphores
message queues
```

### Simple:

> **Access other processes' IPC resources despite normal permission restrictions.**

---

# 19. CAP_SYS_MODULE

Allows loading/unloading Linux kernel modules.

For example:

```bash
modprobe module
```

### Simple:

> **Load code/modules into the Linux kernel.**

⚠️ **Extremely dangerous in a container.**

If a container can load kernel modules, you're giving it a very powerful path toward affecting the host kernel.

---

# 20. CAP_SYS_RAWIO

Allows certain raw I/O operations.

This can involve access to low-level hardware/I/O interfaces.

### Simple:

> **Perform low-level hardware I/O operations.**

⚠️ Extremely powerful.

---

# 21. CAP_SYS_CHROOT

Allows using:

```bash
chroot
```

### Simple:

> **Change the process's apparent root filesystem.**

Example:

```bash
chroot /newroot
```

Important:

> `chroot` is **not a security boundary by itself**.

---

# 22. CAP_SYS_PTRACE

Allows tracing/debugging other processes under applicable kernel restrictions.

For example:

```bash
ptrace()
```

Tools such as:

```text
gdb
strace
```

can depend on this.

### Simple:

> **Inspect/control other processes for debugging.**

⚠️ Very sensitive.

---

# 23. CAP_SYS_PACCT

Allows process accounting control.

### Simple:

> **Control Linux process accounting.**

Rarely needed by normal containers.

---

# 24. CAP_SYS_ADMIN

🚨 **One of the most dangerous capabilities.**

It covers a very large collection of system administration operations.

It can be involved in:

* mounting filesystems
* namespace-related operations
* system administration operations
* various kernel/system controls

It is often described as:

> **"the new root"**

because it is so broad.

### Simple:

> **Huge collection of system-level privileges.**

⚠️ Avoid adding it unless absolutely necessary.

Bad:

```yaml
capabilities:
  add:
    - SYS_ADMIN
```

Ask yourself:

> Why exactly does this application need SYS_ADMIN?

---

# 25. CAP_SYS_BOOT

Allows certain system reboot/kexec-related operations.

### Simple:

> **Perform certain system boot/reboot operations.**

⚠️ Not appropriate for normal applications.

---

# 26. CAP_SYS_NICE

Allows changing process scheduling/priority and certain CPU affinity/scheduling settings.

For example:

```bash
nice
renice
```

### Simple:

> **Change how the Linux scheduler prioritizes your process.**

Useful in some:

* HPC
* real-time
* performance-sensitive applications

---

# 27. CAP_SYS_RESOURCE

Allows bypassing certain resource limits.

Examples can include:

```text
file size limits
locked memory limits
certain IPC/resource limits
```

### Simple:

> **Override certain Linux resource limits.**

---

# 28. CAP_SYS_TIME

Allows changing the system clock.

### Simple:

> **Change the system time.**

⚠️ Very sensitive.

Changing system time can affect:

```text
TLS
Kerberos
certificates
logs
distributed systems
```

---

# 29. CAP_SYS_TTY_CONFIG

Allows certain privileged operations involving TTY devices.

### Simple:

> **Perform certain low-level terminal/TTY operations.**

Rarely needed.

---

# 30. CAP_MKNOD

Allows creating special filesystem nodes.

For example:

```bash
mknod
```

Special files can represent devices.

### Simple:

> **Create special files/device nodes.**

⚠️ Security-sensitive in containers.

---

# 31. CAP_LEASE

Allows establishing file leases.

### Simple:

> **Control certain file lease mechanisms.**

Rarely needed by ordinary applications.

---

# 32. CAP_AUDIT_WRITE

Allows writing records to the Linux audit system.

### Simple:

> **Write messages/events to the Linux audit system.**

---

# 33. CAP_AUDIT_CONTROL

Allows controlling the Linux audit subsystem.

### Simple:

> **Control Linux auditing.**

More powerful than merely writing audit records.

---

# 34. CAP_SETFCAP

Allows setting file capabilities.

For example, assigning capabilities to an executable.

### Simple:

> **Give Linux capabilities to files/programs.**

Security-sensitive.

---

# 35. CAP_MAC_OVERRIDE

MAC = **Mandatory Access Control**.

Allows bypassing certain MAC restrictions.

This can relate to security systems such as:

```text
Smack
```

### Simple:

> **Bypass certain mandatory security controls.**

---

# 36. CAP_MAC_ADMIN

Allows administration of certain MAC systems such as Smack.

### Simple:

> **Manage certain mandatory access-control policies.**

---

# 37. CAP_SYSLOG

Allows certain privileged kernel logging operations.

### Simple:

> **Access/control certain kernel log information.**

---

# 38. CAP_WAKE_ALARM

Allows triggering system wakeup alarms.

### Simple:

> **Schedule alarms that can wake the system.**

Not normally relevant to containers.

---

# 39. CAP_BLOCK_SUSPEND

Allows blocking system suspend under certain conditions.

### Simple:

> **Prevent the system from going to sleep/suspend.**

Not normally needed in application containers.

---

# 40. CAP_AUDIT_READ

Allows reading from the Linux audit subsystem via its audit netlink interface.

### Simple:

> **Read Linux audit information.**

---

# 41. CAP_PERFMON

Allows certain performance monitoring operations.

This is used by tools involving:

```text
perf
performance counters
kernel performance monitoring
```

### Simple:

> **Monitor low-level system performance.**

⚠️ Sensitive because performance interfaces can expose information about the system.

---

# 42. CAP_BPF

Allows certain privileged BPF operations.

BPF/eBPF can be used for:

```text
networking
tracing
security
observability
kernel instrumentation
```

### Simple:

> **Use powerful Linux eBPF functionality.**

⚠️ Very security-sensitive.

---

# 43. CAP_CHECKPOINT_RESTORE

Allows certain checkpoint/restore operations and related privileged functionality.

Used by technologies involving:

```text
CRIU
```

### Simple:

> **Checkpoint and restore processes.**

Usually not required by ordinary applications.

---

# 44. Quick capability cheat sheet

Here is the list in a more useful format:

| Capability               | Simple meaning                     | Risk  |
| ------------------------ | ---------------------------------- | ----- |
| `CAP_CHOWN`              | Change file owner                  | 🟡    |
| `CAP_DAC_OVERRIDE`       | Bypass file permissions            | 🔴    |
| `CAP_DAC_READ_SEARCH`    | Bypass read/search permissions     | 🔴    |
| `CAP_FOWNER`             | Bypass some ownership checks       | 🟠    |
| `CAP_FSETID`             | Preserve setuid/setgid bits        | 🟡    |
| `CAP_KILL`               | Signal other processes             | 🟠    |
| `CAP_SETGID`             | Change group ID                    | 🟠    |
| `CAP_SETUID`             | Change user ID                     | 🔴    |
| `CAP_SETPCAP`            | Manipulate capabilities            | 🔴    |
| `CAP_LINUX_IMMUTABLE`    | Change immutable/append-only flags | 🟡    |
| `CAP_NET_BIND_SERVICE`   | Bind ports <1024                   | 🟢    |
| `CAP_NET_BROADCAST`      | Network broadcasts                 | 🟡    |
| `CAP_NET_ADMIN`          | Configure networking               | 🔴    |
| `CAP_NET_RAW`            | Raw network packets                | 🟠    |
| `CAP_IPC_LOCK`           | Lock memory in RAM                 | 🟡    |
| `CAP_IPC_OWNER`          | Bypass IPC permissions             | 🟠    |
| `CAP_SYS_MODULE`         | Load kernel modules                | 🔴🔴  |
| `CAP_SYS_RAWIO`          | Raw hardware I/O                   | 🔴🔴  |
| `CAP_SYS_CHROOT`         | Use chroot                         | 🟡    |
| `CAP_SYS_PTRACE`         | Trace other processes              | 🔴    |
| `CAP_SYS_PACCT`          | Process accounting                 | 🟡    |
| `CAP_SYS_ADMIN`          | Huge set of system admin powers    | 🔴🔴  |
| `CAP_SYS_BOOT`           | Boot/reboot operations             | 🔴    |
| `CAP_SYS_NICE`           | Change scheduling priority         | 🟡    |
| `CAP_SYS_RESOURCE`       | Override resource limits           | 🟠    |
| `CAP_SYS_TIME`           | Change system clock                | 🔴    |
| `CAP_SYS_TTY_CONFIG`     | TTY administration                 | 🟡    |
| `CAP_MKNOD`              | Create device/special files        | 🔴    |
| `CAP_LEASE`              | File leases                        | 🟡    |
| `CAP_AUDIT_WRITE`        | Write audit records                | 🟢/🟡 |
| `CAP_AUDIT_CONTROL`      | Control auditing                   | 🔴    |
| `CAP_SETFCAP`            | Set file capabilities              | 🔴    |
| `CAP_MAC_OVERRIDE`       | Bypass some MAC controls           | 🔴    |
| `CAP_MAC_ADMIN`          | Manage MAC policies                | 🔴    |
| `CAP_SYSLOG`             | Privileged kernel logging          | 🟠    |
| `CAP_WAKE_ALARM`         | Wake system with alarms            | 🟢    |
| `CAP_BLOCK_SUSPEND`      | Prevent system suspend             | 🟢    |
| `CAP_AUDIT_READ`         | Read audit information             | 🟠    |
| `CAP_PERFMON`            | Performance monitoring             | 🟠    |
| `CAP_BPF`                | Privileged eBPF operations         | 🔴    |
| `CAP_CHECKPOINT_RESTORE` | Checkpoint/restore processes       | 🟠    |

---

# 45. Which capabilities are the most dangerous?

For DevOps/Kubernetes, pay special attention to these:

```text
🔴 CAP_SYS_ADMIN
🔴 CAP_SYS_MODULE
🔴 CAP_SYS_RAWIO
🔴 CAP_DAC_OVERRIDE
🔴 CAP_SYS_PTRACE
🔴 CAP_NET_ADMIN
🔴 CAP_SETUID
🔴 CAP_SETGID
🔴 CAP_MKNOD
🔴 CAP_BPF
🔴 CAP_SETFCAP
```

Especially:

```text
CAP_SYS_ADMIN
```

Don't casually add it.

---

# 46. Kubernetes: Drop ALL capabilities

A very good security practice is:

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
```

Now:

```text
Container
    ↓
No additional Linux capabilities
```

Then add only what you actually need.

For example, an HTTP server that needs to bind to port 80:

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_BIND_SERVICE
```

This is much better than:

```yaml
privileged: true
```

---

# 47. Example: Network application

Suppose your application needs to modify routes.

You might need:

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_ADMIN
```

Then:

```text
Application
     ↓
CAP_NET_ADMIN
     ↓
Can perform required network administration
```

Instead of:

```yaml
privileged: true
```

which gives it far more power than necessary.

---

# 48. Example: `ping`

If your application genuinely needs raw sockets:

```yaml
securityContext:
  capabilities:
    drop:
      - ALL
    add:
      - NET_RAW
```

Then:

```text
CAP_NET_RAW
     ↓
raw sockets
     ↓
ping / packet-level operations
```

Again, don't automatically give:

```text
NET_ADMIN
```

if all you need is:

```text
NET_RAW
```

---

# 49. Container privileges beyond capabilities

You should also memorize these Kubernetes settings:

```yaml
securityContext:
  privileged: true
```

```yaml
hostNetwork: true
```

```yaml
hostPID: true
```

```yaml
hostIPC: true
```

```yaml
securityContext:
  allowPrivilegeEscalation: true
```

```yaml
volumes:
- hostPath:
    path: /
```

These are **not Linux capabilities**, but they can dramatically change the security boundary.

---

# 50. Think about security in this order

When looking at a Pod, ask:

```text
1. Is it privileged?
       ↓
2. Is it using hostNetwork?
       ↓
3. Is it using hostPID?
       ↓
4. Is it using hostIPC?
       ↓
5. Is it mounting hostPath?
       ↓
6. Which Linux capabilities does it have?
       ↓
7. Can it escalate privileges?
       ↓
8. Is it running as root?
       ↓
9. What seccomp profile is used?
       ↓
10. What AppArmor/SELinux policy applies?
       ↓
11. What ServiceAccount does it use?
       ↓
12. What RBAC permissions does that account have?
       ↓
13. What network traffic is allowed?
```

That's how you should analyze a container from a security perspective.

### Most important mental model

```text
                   Container Privileges
                          │
            ┌─────────────┴─────────────┐
            │                           │
      Kubernetes                     Linux
       privileges                  capabilities
            │                           │
    ┌───────┼────────┐          ┌───────┼────────┐
    │       │        │          │       │        │
privileged hostNet hostPID   NET_ADMIN SETUID SYS_ADMIN
    │       │        │          │       │        │
    └───────┴────────┘          └───────┴────────┘
                 │
                 ↓
          Container attack surface
```

**Best practice:** start with `drop: [ALL]`, run as non-root, set `allowPrivilegeEscalation: false`, use `seccompProfile: RuntimeDefault`, and add **only the specific capability the application demonstrably requires**.
