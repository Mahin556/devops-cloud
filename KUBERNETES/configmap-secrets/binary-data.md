### `binaryData` Field
* Stores binary data encoded as base64.
* Each key is the file name; the value is base64-encoded content.
* Kubernetes decodes the data automatically when mounted as a volume.

* Why binaryData?
  * Some apps require non-text files like certificates, keys, images, or compiled files.
  * `data` cannot store these because it expects UTF-8 strings.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-config
binaryData:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg==  # base64-encoded certificate
  tls.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQo=  # base64-encoded private key
```
* Keys in binaryData must be unique, cannot overlap with data.
* Ideal for small binaries (<1 MiB due to ConfigMap size limits).

* You can have both in a single ConfigMap, e.g.:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mixed-config
data:
  app_name: "my-app"
binaryData:
  config.bin: U29tZSBiaW5hcnkgY29uZmlnCg==

---

apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
    - name: demo-container
      image: busybox
      command: ["sh", "-c", "ls /config && cat /config/app_name && cat /config/config.bin"]
      env:
      - name: app_name
        valueFrom:
          configMapKeyRef:
            name: mixed-config
            key: app_name
      volumeMounts:
        - name: config-volume
          mountPath: /config
  volumes:
    - name: config-volume
      configMap:
        name: mixed-config
```
* When mounted as a volume:
  * app_name → /config/app_name
  * config.bin → /config/config.bin (decoded automatically)

* No built-in version control (use Git for that).
* Config errors can cause Pod startup issues (e.g., CreateContainerConfigError).
