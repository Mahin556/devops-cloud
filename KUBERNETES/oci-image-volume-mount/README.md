# Mount Static Assets from an OCI Image into a Kubernetes Pod

## Objective

Deploy an nginx Pod that serves a custom `index.html` from an OCI image, without using an init container or building a custom nginx image.

- Pod name: `nginx-1`
- Namespace: `default`
- Image volume: `registry.iximiuz.com/welcome-page:v1`
- Mount path: `/usr/share/nginx/html`
- Result: nginx on port 80 serves the custom welcome page.

---

## What You Are Building

```text
OCI image: registry.iximiuz.com/welcome-page:v1
        │
        │ pulled by kubelet
        ▼
Pod: nginx-1
  ├── container: nginx
  │     └── mounts image volume at /usr/share/nginx/html
  └── volume: image
        └── reference: registry.iximiuz.com/welcome-page:v1
```

The image’s root filesystem is exposed as a read-only volume inside the Pod. When mounted at `/usr/share/nginx/html`, it replaces nginx’s default HTML directory, so nginx serves the custom `index.html` automatically.

---

## Pod Manifest

Create a file called `nginx-1.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-1
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: welcome-page
      mountPath: /usr/share/nginx/html
      readOnly: true
  volumes:
  - name: welcome-page
    image:
      reference: registry.iximiuz.com/welcome-page:v1
      pullPolicy: IfNotPresent
```

Apply it:

```bash
kubectl apply -f nginx-1.yaml
```

Or apply directly from stdin:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nginx-1
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: welcome-page
      mountPath: /usr/share/nginx/html
      readOnly: true
  volumes:
  - name: welcome-page
    image:
      reference: registry.iximiuz.com/welcome-page:v1
      pullPolicy: IfNotPresent
EOF
```

---

## Verify the Pod

Check that the Pod is running:

```bash
kubectl get pod nginx-1 -o wide
```

Wait for `STATUS` to become `Running`.

If it is stuck, inspect events:

```bash
kubectl describe pod nginx-1
```

---

## Verify the Mounted Files

List the mounted directory:

```bash
kubectl exec nginx-1 -- ls -la /usr/share/nginx/html
```

Show the `index.html`:

```bash
kubectl exec nginx-1 -- cat /usr/share/nginx/html/index.html
```

You should see the custom welcome page content from the OCI image, not the default nginx page.

---

## Verify nginx Serves the Page

Get the Pod IP:

```bash
POD_IP=$(kubectl get pod nginx-1 -o jsonpath='{.status.podIP}')
echo "$POD_IP"
```

Curl the Pod from inside the cluster:

```bash
kubectl run --rm -it --restart Never \
  --image curlimages/curl:latest -- \
  curl -v "$POD_IP:80"
```

Alternatively, use port-forward from your workstation:

```bash
kubectl port-forward pod/nginx-1 8080:80
```

Then in another terminal:

```bash
curl -v http://localhost:8080
```

You should get the custom welcome page.

---

## Theory: What Is a Kubernetes Image Volume?

A Kubernetes **image volume** is a volume type that pulls an OCI image from a registry and exposes its root filesystem as a read-only volume.

Syntax:

```yaml
volumes:
- name: <volume-name>
  image:
    reference: <registry>/<repo>/<image>:<tag>
    pullPolicy: IfNotPresent
```

Key properties:

- The image is pulled by the kubelet using the same mechanism as container images.
- No process from the image is run.
- The image’s files are mounted into the Pod at the specified `mountPath`.
- The volume is read-only.
- The mount hides whatever was at that path in the container image.

In this challenge:

- The OCI image contains a custom `index.html`.
- nginx normally serves files from `/usr/share/nginx/html`.
- Mounting the image volume at that exact path replaces nginx’s default HTML directory.
- nginx serves the custom `index.html` without any extra copying.

---

## How It Works Under the Hood

OCI images are made of layers. Normally, a container runtime pulls the image, unpacks the layers, and runs a process from it.

An image volume reuses the pull and unpack steps but does not run anything. Instead, the container runtime mounts the resulting root filesystem as a volume into the Pod.

```text
Registry
   │
   │ pull
   ▼
Container runtime
   │
   │ unpack layers
   ▼
Read-only filesystem
   │
   │ mount into Pod
   ▼
/usr/share/nginx/html
```

Because the volume is mounted over `/usr/share/nginx/html`, the original nginx `index.html` is hidden. The image’s `index.html` becomes the visible file.

---

## Why This Is Better Than Alternatives

### Init container + emptyDir

Traditional approach:

1. Init container pulls the artifact image.
2. It copies files into an `emptyDir`.
3. nginx mounts the `emptyDir`.

Drawbacks:

- Extra container and lifecycle.
- Copy overhead.
- Writable `emptyDir` when not needed.

### Custom nginx image

You could build a new nginx image with the custom `index.html` baked in.

Drawbacks:

- Need to rebuild and push an image for every asset change.
- Mixes application and static assets.
- Larger image.

### Image volume

- No init container.
- No custom nginx image.
- No copy step.
- Immutable, versioned artifact.
- Read-only by design.

---

## Important Considerations

- **Kubernetes version**: Image volumes are GA in Kubernetes v1.36. On older versions, the `ImageVolume` feature gate may be required.
- **Container runtime support**: The container runtime must support image volumes.
- **Private registries**: If the image is private, add `imagePullSecrets` to the Pod.
- **Read-only**: The mounted volume cannot be written to. Do not point nginx logs or cache there.
- **Path mapping**: The root of the image becomes the `mountPath`. If the image contains `index.html` at its root, it appears at `/usr/share/nginx/html/index.html`.
- **Pull policy**: `IfNotPresent` avoids pulling every time. Use `Always` if the tag is mutable.

---

## Troubleshooting

### Pod stuck in `ContainerCreating`

```bash
kubectl describe pod nginx-1
```

Look for image pull errors, volume mount failures, or feature gate issues.

### nginx serves the default page

Check the mount path:

```bash
kubectl exec nginx-1 -- ls -la /usr/share/nginx/html
```

If the custom `index.html` is missing, the volume may not be mounted correctly, or the image may not contain the file at the expected location.

### Permission denied

Check file permissions inside the image:

```bash
kubectl exec nginx-1 -- ls -la /usr/share/nginx/html
```

nginx usually runs as root or the `nginx` user. The files should be readable.

### Image pull error

- Verify the image reference.
- Check registry credentials.
- Add `imagePullSecrets` if needed.

---

## Cleanup

Delete the Pod:

```bash
kubectl delete pod nginx-1
```

---

## Summary

The complete solution is a single Pod with an image volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-1
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: welcome-page
      mountPath: /usr/share/nginx/html
      readOnly: true
  volumes:
  - name: welcome-page
    image:
      reference: registry.iximiuz.com/welcome-page:v1
      pullPolicy: IfNotPresent
```

This mounts the OCI image’s filesystem directly at nginx’s HTML root. No init container, no custom nginx image, no copy step. nginx serves the custom welcome page from the OCI image.