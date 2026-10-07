# Editing a File in a Running Pod with Restricted Permissions

This challenge combines two obstacles: the container's user cannot write to the target file, and you must not restart the Pod. The solution is to attach a **privileged ephemeral container** and write the file through the target container's `/proc/<PID>/root` path.

Here is the full walkthrough, including why each step is needed and what to do when the default approach fails.

---

## 1. Understand the Problem

The Pod `web-server` in the `default` namespace runs a single container serving static files from `/var/www/html`. You need to edit `/var/www/html/index.html`:

- Replace `Hello World` with `Hello Labs`.
- Add `Practice for the win!` somewhere in the file.

Constraints:

- **Do not restart the Pod.** Changing the Pod's spec in a way that forces recreation (e.g., changing the image, deleting the container) is off-limits.
- The container **does have a shell** (you can `kubectl exec`), but the container's user **does not have write permission** on the file.

So the file's owner or mode blocks your write, and you cannot simply `kubectl cp` it back after downloading it — the same permission problem applies to uploads.

---

## 2. Reconnaissance: Confirm the Constraints

### Check the Pod

```bash
kubectl get pod web-server -o wide
```

### Confirm you can exec

```bash
kubectl exec -it web-server -- sh
```

Inside the container, inspect the file and the user:

```bash
id
ls -l /var/www/html/index.html
cat /var/www/html/index.html
```

You will likely see the file owned by `root` with mode `644`, while the container user is something like `nginx` or a non-root UID. That is why a direct write fails:

```bash
echo "test" >> /var/www/html/index.html
# sh: can't create /var/www/html/index.html: Permission denied
```

### Try the naive approach

From your host:

```bash
kubectl cp web-server:/var/www/html/index.html ./index.html
```

This **works** — reading is allowed.

Edit the file locally:

```bash
sed -i 's/Hello World/Hello Labs/' ./index.html
echo 'Practice for the win!' >> ./index.html
```

Now try to copy it back:

```bash
kubectl cp ./index.html web-server:/var/www/html/index.html
```

This **fails** with a permission error, because the container's user cannot overwrite a file owned by `root`.

You cannot `chown` or `chmod` from inside the container either — the same permission restriction applies.

---

## 3. Why `kubectl debug` Alone Is Not Enough

`kubectl debug` can attach an ephemeral container, and you can target the `app` container so the debug container shares its PID namespace:

```bash
kubectl debug -it web-server --image=alpine --target=app
```

Inside, you can see the target's processes:

```bash
ps aux
```

And its root filesystem is exposed via `/proc/1/root`:

```bash
ls /proc/1/root/var/www/html/
```

But when you try to write:

```bash
echo "test" >> /proc/1/root/var/www/html/index.html
# Permission denied
```

**Why?** Even if the ephemeral container's user is `root`, the debug container created by `kubectl debug` is **not privileged** by default. It runs with a restricted security context and cannot bypass filesystem permissions on the target container's root filesystem. `kubectl debug` does not expose a flag to set `privileged: true` on the ephemeral container it creates. The `--profile` values (`legacy`, `baseline`, `restricted`, `netadmin`, `sysadmin`) adjust capabilities but do not give you the precise security context you need here.

> `--profile=sysadmin` may help with some capabilities, but for full root-level writes to another container's rootfs, the cleanest path is a **manual privileged ephemeral container**.

---

## 4. The Right Tool: A Manual Privileged Ephemeral Container

The Ephemeral Containers API gives you full control over the container spec, including its `securityContext`. You can create a container that runs as root **and** is privileged, which bypasses the filesystem permission check on the target's rootfs.

### Step 1: Start `kubectl proxy`

```bash
kubectl proxy &
```

This runs a local proxy to the Kubernetes API on `localhost:8001`, so you can send authenticated `curl` requests without fiddling with tokens.

### Step 2: Patch the Pod to add a privileged ephemeral container

```bash
curl -Lvk localhost:8001/api/v1/namespaces/default/pods/web-server/ephemeralcontainers \
  -XPATCH \
  -H 'Content-Type: application/strategic-merge-patch+json' \
  -d '
{
    "spec":
    {
        "ephemeralContainers":
        [
            {
                "name": "debug-priv",
                "command": ["sh"],
                "targetContainerName": "app",
                "image": "alpine",
                "stdin": true,
                "tty": true,
                "securityContext": {
                    "privileged": true,
                    "runAsUser": 0,
                    "runAsNonRoot": false
                }
            }
        ]
    }
}'
```

Key fields:

| Field | Why it matters |
|---|---|
| `targetContainerName: app` | Joins the `app` container's PID namespace, so `/proc/1/root` points at the app's filesystem. |
| `image: alpine` | Provides a shell and basic tools. |
| `stdin: true`, `tty: true` | Enables interactive attach. |
| `securityContext.privileged: true` | Allows root to bypass normal filesystem permission checks on the target's rootfs. |
| `securityContext.runAsUser: 0` | Ensures the shell runs as root. |

### Step 3: Attach to the ephemeral container

```bash
kubectl attach -it web-server -c debug-priv
```

You now have a root shell inside a container that shares the app container's process namespace.

### Step 4: Edit the file through `/proc/1/root`

Inside the privileged shell:

```bash
# Confirm you can see the target's filesystem
ls -l /proc/1/root/var/www/html/index.html

# Edit in place
sed -i 's/Hello World/Hello Labs/' /proc/1/root/var/www/html/index.html
echo 'Practice for the win!' >> /proc/1/root/var/www/html/index.html

# Verify
cat /proc/1/root/var/www/html/index.html
```

The changes are written directly to the `app` container's filesystem — no restart required.

---

## 5. Alternative: Use `cdebug`

If `cdebug` is installed (the hints say most playgrounds have it), this is much simpler. `cdebug` wraps the Ephemeral Containers API and lets you request a privileged container and directly land in the target's filesystem.

```bash
cdebug exec --privileged -it web-server
```

Once inside, you are effectively operating in the target container's filesystem. You can edit the file directly:

```bash
sed -i 's/Hello World/Hello Labs/' /var/www/html/index.html
echo 'Practice for the win!' >> /var/www/html/index.html
```

`cdebug` sets up the privileged ephemeral container, targets the right container, and exposes the target's rootfs for you — no manual `/proc/1/root` or `curl` patch needed.

Check the tool's help for exact flags:

```bash
cdebug exec --help
```

---

## 6. Alternative: Use `kubectl debug` with a Profile

If you want to stay within `kubectl debug` and avoid `curl`/`cdebug`, try the more permissive profiles. They may give enough capability to write:

```bash
kubectl debug -it web-server --image=alpine --target=app --profile=sysadmin
```

Then inside:

```bash
sed -i 's/Hello World/Hello Labs/' /proc/1/root/var/www/html/index.html
echo 'Practice for the win!' >> /proc/1/root/var/www/html/index.html
```

If `sysadmin` still fails with permission errors, fall back to the manual privileged ephemeral container in section 4. The `sysadmin` profile is more capable than the default but is not guaranteed to bypass all filesystem restrictions on another container's rootfs.

---

## 7. Verify the Change

From your host, hit the web server and check the content.

Get the Pod IP:

```bash
kubectl get pod web-server -o jsonpath='{.status.podIP}'
```

Then:

```bash
curl http://<pod-ip>:8080/
```

You should see the updated content containing `Hello Labs` and `Practice for the win!`.

Or, from inside the original container:

```bash
kubectl exec web-server -- cat /var/www/html/index.html
```

---

## 8. Cleanup

Ephemeral containers cannot be removed from a Pod once added. If the Pod is recreated, they disappear. For this challenge, that is fine — leaving the debug container in the Pod's spec does not affect the running app. If you want to stop `kubectl proxy`:

```bash
kill %1
```

---

## 9. Why This Works — The Mental Model

| Layer | What it controls | How it blocks you |
|---|---|---|
| Container user | Process UID/GID inside the container | Non-root user cannot write a root-owned file |
| Filesystem permissions | File mode and ownership | `644` root-owned file is not writable by non-root |
| Ephemeral container security context | Capabilities and privilege | Unprivileged root still subject to normal permission checks |
| `/proc/<PID>/root` | Symlink to target container's rootfs | Only accessible if the debug container can read/enter it |

- A normal `kubectl debug` ephemeral container runs as a **non-privileged** user. Even as root, without `CAP_DAC_OVERRIDE` (which `privileged: true` grants), it cannot bypass file mode checks.
- Setting `privileged: true` grants all capabilities, including `CAP_DAC_OVERRIDE` and `CAP_DAC_READ_SEARCH`, which let root write to files regardless of their mode.
- `targetContainerName` makes the ephemeral container share the target's PID namespace, so `PID 1` in the debug shell is the target's main process, and `/proc/1/root` resolves to the target's filesystem root.

That combination — **shared PID namespace + privileged root** — is what lets you edit the file in place without restarting the Pod.

---

## 10. Summary of Commands

| Task | Command |
|---|---|
| Inspect the file | `kubectl exec -it web-server -- sh` then `ls -l /var/www/html/index.html` |
| Try `kubectl cp` out (works) | `kubectl cp web-server:/var/www/html/index.html ./index.html` |
| Try `kubectl cp` back (fails) | `kubectl cp ./index.html web-server:/var/www/html/index.html` |
| Quick try with `kubectl debug` | `kubectl debug -it web-server --image=alpine --target=app --profile=sysadmin` |
| Manual privileged ephemeral container | `kubectl proxy &` then `curl ... -XPATCH ...` (see section 4) |
| Attach to it | `kubectl attach -it web-server -c debug-priv` |
| Edit via target rootfs | `sed -i ... /proc/1/root/var/www/html/index.html` |
| Alternative with `cdebug` | `cdebug exec --privileged -it web-server` |
| Verify | `curl http://<pod-ip>:8080/` |

After this, the file contains the required phrases, the Pod has not restarted, and the only spec change is the addition of an ephemeral container — which is allowed and does not trigger a restart.