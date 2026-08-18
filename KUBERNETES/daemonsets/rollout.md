#### Updating a DaemonSet
* By default, Pods are replaced **one at a time** (rolling update).
* DaemonSets support **two update strategies** under `.spec.updateStrategy`:
  * **RollingUpdate** (default): Replace Pods gradually.
  * **OnDelete**: New Pods are created only after you manually delete the old ones.

* **OnDelete**
* DaemonSet controller does **not** automatically replace Pods after a template change.
* You must **manually delete Pods** → only then the controller creates new ones.
* Best for **critical system components** (e.g., networking plugins) where you want **full control** over restarts.
```bash
kubectl create namespace logging
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-ondelete
  namespace: logging
spec:
  updateStrategy:
    type: OnDelete
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            cpu: 200m
            memory: 200Mi
```
* Get image
  ```bash
  kubectl describe daemonset fluentd-ondelete -n logging | grep -i image
  Image:      quay.io/fluentd_elasticsearch/fluentd:v2.5.2

  kubectl describe pods fluentd-ondelete-b2j5l -n logging | grep -m 1 Image
  Image:          quay.io/fluentd_elasticsearch/fluentd:v2.5.2
  ```

* update image
  ```bash
  kubectl set image daemonset fluentd-ondelete fluentd=ewok/fluentd:v2.5.1 -n logging

  kubectl describe daemonset fluentd-ondelete -n logging | grep -i image
  Image:      ewok/fluentd:v2.5.1

  kubectl describe pods fluentd-ondelete-b2j5l -n logging | grep -m 1 Image
  Image:          quay.io/fluentd_elasticsearch/fluentd:v2.5.2
  ```

* If you change the image version here, Pods **stay old** until you delete them:
  ```bash
  kubectl delete pod -l app=fluentd -n logging

  kubectl describe pods fluentd-ondelete-p5pqz -n logging | grep -m 1 Image
  Image:          ewok/fluentd:v2.5.1
  ```
* DaemonSet controller then replaces them with new Pods.

---

* **RollingUpdate Strategy (default)**
* When you update the DaemonSet Pod spec, old Pods are automatically killed and replaced with new ones.
* Controlled by `rollingUpdate.maxUnavailable`:
    * `maxUnavailable: 1` → ensures that only 1 Pod is unavailable at a time.
    * You can use absolute numbers (e.g., `2`) or percentages (e.g., `20%`).
* Ensures **gradual replacement** across nodes.
```bash
kubectl create namespace logging
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-rolling
  namespace: logging
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1   # can be "1" or "20%"
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
          limits:
            memory: 200Mi
```
```bash
kubectl set image daemonset fluentd-rolling fluentd=quay.io/fluentd_elasticsearch/fluentd:v2.6.0 -n logging

kubectl rollout status daemonset fluentd-rolling -n logging

kubectl describe pod fluentd-rolling-lb926 -n logging | grep -m 1 Image
Image:          quay.io/fluentd_elasticsearch/fluentd:v2.6.0

kubectl rollout undo daemonset fluentd-rolling -n logging #If something goes wrong with an update

kubectl describe pod fluentd-rolling-wz576 -n logging | grep -m 1 Image
Image:          quay.io/fluentd_elasticsearch/fluentd:v2.5.2

kubectl rollout undo daemonset fluentd-rolling -n logging --to-revision=2

kubectl delete daemonset fluentd-rolling -n logging

kubectl delete daemonset fluentd-rolling -n logging --cascade=false #Keep Pods running but remove DaemonSet controller (orphan Pods)
#This is useful if you want Pods to keep running independently after deleting the DaemonSet.

kubectl delete daemonset fluentd-rolling -n logging --cascade=false 
warning: --cascade=false is deprecated (boolean value) and can be replaced with --cascade=orphan.
daemonset.apps "fluentd-rolling" deleted from logging namespace
```


* **Different Ways to Trigger a RollingUpdate in DaemonSets**
Rolling updates happen **whenever the Pod template changes**.
Here are the common ways:

1. **Update the image**
```bash
kubectl set image daemonset fluentd-rolling fluentd=quay.io/fluentd_elasticsearch/fluentd:v2.6.0 -n logging
```
This replaces Pods gradually (following `maxUnavailable`).

2. **Patch the DaemonSet**
Apply a patch to change spec fields (like image, env, args):
```bash
kubectl patch daemonset fluentd-rolling -n logging \
  -p '{"spec": {"template": {"spec": {"containers": [{"name": "fluentd","image":"quay.io/fluentd_elasticsearch/fluentd:v2.6.1"}]}}}}'
```

3. **Edit the DaemonSet YAML**
```bash
kubectl edit daemonset fluentd-rolling -n logging
```
Modify the Pod spec (image, env, resource limits). The controller starts rolling out updates automatically.

4. **Apply a new manifest**
If you have a YAML with changes:
```bash
kubectl apply -f fluentd-rolling.yaml
```

5. **Force a rolling restart (without changing spec)**
Sometimes you want to restart Pods to pick up ConfigMap/Secret changes without changing the container image. You can do this with an **annotation trick**:
```bash
kubectl patch daemonset fluentd-rolling -n logging \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"kubectl.kubernetes.io/restartedAt\":\"$(date +%Y-%m-%dT%H:%M:%S%z)\"}}}}}"

kubectl rollout restart fluentd-rolling -n logging
```
This updates the Pod template’s annotation → Kubernetes treats it as a spec change → triggers a rolling restart.


* Use **RollingUpdate** for most DaemonSets (monitoring, logging).
* Use **OnDelete** for sensitive system-level DaemonSets (CNI plugins).
* Always check rollout progress (`kubectl rollout status`).
* Keep **resource limits** defined to avoid node pressure during rollout.
* Use `maxUnavailable=0` for **zero downtime upgrades** (but slower rollout).