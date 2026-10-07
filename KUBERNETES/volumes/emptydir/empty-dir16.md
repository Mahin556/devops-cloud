```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myvolumes-pod
spec:
  containers:
  - image: alpine
    imagePullPolicy: IfNotPresent
    name: myvolumes-container

    command: ['sh', '-c', 'echo Container 1 is Running ; sleep 3600']

    volumeMounts:
    - mountPath: /demo
      name: demo-volume
  volumes:
  - name: demo-volume
    emptyDir:
      medium: Memory     
```
```bash
kubectl exec myvolumes-pod -i -t -- /bin/sh

/ # df -h
Filesystem                Size      Used Available Use% Mounted on
tmpfs                    64.0M         0     64.0M   0% /dev
tmpfs                   932.3M         0    932.3M   0% /sys/fs/cgroup
tmpfs                   932.3M         0    932.3M   0% /demo
```
* Default behavior:
  * RAM-based emptyDir uses half of node’s RAM
  * Example:
    * Node RAM = 1.8 GB
    * emptyDir tmpfs = ~900 MB

```bash
dd if=/dev/urandom of=/demo/largefile bs=10M count=10 #Write 100MB:

df -h /demo
Filesystem                Size      Used Available Use% Mounted on
tmpfs                   932.3M    100.0M   832.3M   11% /demo

dd if=/dev/urandom of=/demo/largefile bs=10M count=20 #Write another 100MB:
tmpfs                   932.3M    200.0M   732.3M   21% /demo
```