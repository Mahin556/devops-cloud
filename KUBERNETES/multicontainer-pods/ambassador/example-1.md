## 0. Create the ConfigMap

```bash
kubectl create configmap ambassador-token-config --from-file=default.conf=$HOME/default.conf
```

Or declared in YAML. The `~/default.conf` provided by setup looks like this — nginx listens on `:80`, injects `X-Api-Key`, and forwards to the `httpbin` Service in the `infra` namespace:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ambassador-token-config
data:
  default.conf: |
    server {
      listen 80;

      location / {
        proxy_set_header X-Api-Key "supersecret-token";
        proxy_pass http://httpbin.infra:80;
      }
    }
```

`proxy_set_header` is the nginx directive that adds/replaces a header on the **outbound** request. Note the header name is `X-Api-Key` on the wire (httpbin reports it as `X-Api-Key` in its JSON response), while nginx accepts the `X-Api-Key` spelling in config.

## 1. Pod

`app` and `ambassador` share the Pod network namespace, so `localhost:80` inside the Pod hits nginx, and nginx forwards to the external `httpbin.infra` Service.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-pod
  labels:
    run: ambassador-pod
spec:
  containers:
    - name: app
      image: busybox
      command:
        - sh
        - -c
        - "while true; do wget -qO- http://localhost:80/headers; echo; sleep 3; done"

    - name: ambassador
      image: nginx:alpine
      ports:
        - containerPort: 80
      volumeMounts:
        - name: ambassador-token-config
          mountPath: /etc/nginx/conf.d

  volumes:
    - name: ambassador-token-config
      configMap:
        name: ambassador-token-config
```

## 2. Apply

```bash
kubectl apply -f configmap.yaml
kubectl apply -f pod.yaml
```

## 3. Verify the mutation

**Path A — direct, bypassing ambassador:** no injected header.

```bash
kubectl exec ambassador-pod -c app -- wget -qO- http://httpbin.infra/headers
# The "headers" object contains only what busybox's wget sent.
# There is NO "X-Api-Key" field.
```

**Path B — through ambassador:** nginx adds the header before forwarding.

```bash
kubectl exec ambassador-pod -c app -- wget -qO- http://localhost:80/headers
# The "headers" object now contains:
#   "X-Api-Key": "supersecret-token"
```

You can also watch the `app` container's own loop, which is doing this every 3 seconds:

```bash
kubectl logs ambassador-pod -c app -f
# Each iteration prints a JSON body whose headers include X-Api-Key.
```

## What's happening, briefly

- The `app` container's `wget` to `http://localhost:80/headers` never leaves the Pod — port 80 on `localhost` is the **ambassador** nginx container (same Pod network namespace).
- nginx's `location /` matches, applies `proxy_set_header X-Api-Key "...";`, and proxies the request out to `http://httpbin.infra:80/headers`.
- `httpbin` echoes back the full request, including the header nginx just added. The `app` container sees a header **it never sent** — the only reason it's there is that nginx mutated the request in flight.
- When you exec into `app` and hit `http://httpbin.infra/headers` directly, that path never touches nginx, so the header is absent. That difference is the proof.

### Troubleshooting notes

- If the Pod won't start, check that the `httpbin` Service actually exists in the `infra` namespace: `kubectl get svc -n infra httpbin`.
- If nginx fails to resolve `httpbin.infra` at startup (rare — nginx resolves `proxy_pass` hostnames at config load for static upstreams), double-check the Service name and namespace, or point directly at the FQDN `httpbin.infra.svc.cluster.local`.
- nginx logs are in the `ambassador` container: `kubectl logs ambassador-pod -c ambassador`.