## 0. Create the ConfigMap from the file

```bash
kubectl create configmap adapter-config --from-file=adapter.conf=$HOME/adapter.conf
```

If you'd rather declare it in YAML (assuming the content of `~/adapter.conf` looks like the block shown — nginx proxies `/legacy-id` on port 80 to the app's real `/uuid` path on `localhost:8080`):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
data:
  adapter.conf: |
    server {
      listen 80;

      # The interface this container "invents" for the app.
      location /legacy-id {
        proxy_pass http://127.0.0.1:8080/uuid;
      }
    }
```

## 1. Pod

Both containers share the Pod network, so `127.0.0.1` in the adapter's nginx config reaches the `app` container's go-httpbin on `:8080`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: adapter-pod
  labels:
    run: adapter-pod
spec:
  containers:
    - name: app
      image: ghcr.io/mccutchen/go-httpbin
      # go-httpbin listens on :8080 by default

    - name: adapter
      image: nginx:alpine
      ports:
        - containerPort: 80
      volumeMounts:
        - name: adapter-config
          mountPath: /etc/nginx/conf.d

  volumes:
    - name: adapter-config
      configMap:
        name: adapter-config
```

## 2. Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: adapter-svc
spec:
  type: ClusterIP
  selector:
    run: adapter-pod
  ports:
    - port: 80
      targetPort: 80
```

## 3. Apply

```bash
kubectl apply -f configmap.yaml
kubectl apply -f pod.yaml
kubectl apply -f service.yaml
```

## 4. Verify the translation

```bash
CLUSTER_IP=$(kubectl get svc adapter-svc -o jsonpath='{.spec.clusterIP}')
# e.g. 10.96.123.45

curl http://${CLUSTER_IP}/legacy-id
# {"uuid":"..."} — the app never heard of /legacy-id,
# nginx rewrote the call to its real /uuid endpoint on localhost.
```

If you're outside the cluster, use `kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- http://<cluster-ip>/legacy-id` or a `kubectl port-forward svc/adapter-svc 8080:80` and `curl http://localhost:8080/legacy-id`.

### What's happening, briefly

- `curl → adapter-svc:80/legacy-id` → hits the **adapter** container (nginx).
- nginx, per `adapter.conf`, matches `location /legacy-id` and proxies to `http://127.0.0.1:8080/uuid`.
- `127.0.0.1` resolves to the **app** container (same Pod network namespace), which happily serves `/uuid`.
- The response flows back out through nginx to the client — the client only ever knew about `/legacy-id`.