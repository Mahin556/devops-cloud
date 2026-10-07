```bash
kubectl create secret docker-registry <secret_name> \
    --docker-server='<your_registry_url>' \
    --docker-username='<your_registry_username>' \
    --docker-password='<your_registry_auth_password>' \
    --docker-email='<your_email_address>'
```
```bash
$ kubectl patch serviceaccount default \
(out) -p '{"imagePullSecrets": [{"name": "<secret_name>"}]}'
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: <pod_name>
spec:
  containers:
    - name: <container-name>
      image: <registry_url>/<repository_name>:<image_tag>
      ports:
      - name: <port_name>
        containerPort: 8080
        protocol: TCP
  imagePullSecrets:
    - name: <secret_name>
```