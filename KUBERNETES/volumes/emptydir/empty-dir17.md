```yaml
apiVersion: v1
kind: Pod
metadata:
  name: disk-size-demo
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - name: ram-cache
      mountPath: /cache
  volumes:
  - name: ram-cache
    emptyDir:
      medium: ""
      sizeLimit: "100Mi"   
```
```bash
controlplane:~$ kubectl exec -it disk-size-demo -c app -- sh
/ # df -h
Filesystem                Size      Used Available Use% Mounted on
overlay                  18.3G      6.0G     12.3G  33% /
tmpfs                    64.0M         0     64.0M   0% /dev
/dev/vda1                18.3G      6.0G     12.3G  33% /cache
/dev/vda1                18.3G      6.0G     12.3G  33% /etc/hosts
/dev/vda1                18.3G      6.0G     12.3G  33% /dev/termination-log
/dev/vda1                18.3G      6.0G     12.3G  33% /etc/hostname
/dev/vda1                18.3G      6.0G     12.3G  33% /etc/resolv.conf
shm                      64.0M         0     64.0M   0% /dev/shm
tmpfs                     1.8G     12.0K      1.8G   0% /var/run/secrets/kubernetes.io/serviceaccount
tmpfs                   951.7M         0    951.7M   0% /proc/acpi
tmpfs                    64.0M         0     64.0M   0% /proc/interrupts
tmpfs                    64.0M         0     64.0M   0% /proc/kcore
tmpfs                    64.0M         0     64.0M   0% /proc/keys
tmpfs                    64.0M         0     64.0M   0% /proc/latency_stats
tmpfs                    64.0M         0     64.0M   0% /proc/timer_list
tmpfs                   951.7M         0    951.7M   0% /proc/scsi
tmpfs                   951.7M         0    951.7M   0% /sys/firmware
```
```bash
$ dd if=/dev/random of=/cache/demo.txt bs=10M count=100
100+0 records in
100+0 records out
1048576000 bytes (1000.0MB) copied, 2.778655 seconds, 359.9MB/s
```
```bash
$ df -h
Filesystem                Size      Used Available Use% Mounted on
overlay                  18.3G      7.0G     11.4G  38% /
tmpfs                    64.0M         0     64.0M   0% /dev
/dev/vda1                18.3G      7.0G     11.4G  38% /cache
/dev/vda1                18.3G      7.0G     11.4G  38% /etc/hosts
/dev/vda1                18.3G      7.0G     11.4G  38% /dev/termination-log
/dev/vda1                18.3G      7.0G     11.4G  38% /etc/hostname
/dev/vda1                18.3G      7.0G     11.4G  38% /etc/resolv.conf
shm                      64.0M         0     64.0M   0% /dev/shm
tmpfs                     1.8G     12.0K      1.8G   0% /var/run/secrets/kubernetes.io/serviceaccount
tmpfs                   951.7M         0    951.7M   0% /proc/acpi
tmpfs                    64.0M         0     64.0M   0% /proc/interrupts
tmpfs                    64.0M         0     64.0M   0% /proc/kcore
tmpfs                    64.0M         0     64.0M   0% /proc/keys
tmpfs                    64.0M         0     64.0M   0% /proc/latency_stats
tmpfs                    64.0M         0     64.0M   0% /proc/timer_list
tmpfs                   951.7M         0    951.7M   0% /proc/scsi
tmpfs                   951.7M         0    951.7M   0% /sys/firmware
```
```bash
$ dd if=/dev/random of=/cache/demo.txt bs=10M count=1000
1000+0 records in
1000+0 records out
10485760000 bytes (9.8GB) copied, 29.092761 seconds, 343.7MB/s
/ # command terminated with exit code 137
```
```bash
controlplane:~$ kubectl exec -it disk-size-demo -c app -- sh
error: cannot exec into a container in a completed pod; current phase is Failed
```
```bash
controlplane:~$ kubectl get pods
NAME             READY   STATUS   RESTARTS   AGE
disk-size-demo   0/1     Error    0          5m27s
```
```bash
controlplane:~$ kubectl describe pod disk-size-demo -- sh
```
```bash
Events:
  Type     Reason     Age    From               Message
  ----     ------     ----   ----               -------
  Normal   Scheduled  5m45s  default-scheduler  Successfully assigned default/disk-size-demo to node01
  Normal   Pulling    5m45s  kubelet            Pulling image "busybox"
  Normal   Pulled     5m44s  kubelet            Successfully pulled image "busybox" in 692ms (692ms including waiting). Image size: 2224358 bytes.
  Normal   Created    5m44s  kubelet            Created container: app
  Normal   Started    5m44s  kubelet            Started container app
  Warning  Evicted    40s    kubelet            Usage of EmptyDir volume "ram-cache" exceeds the limit "100Mi".
  Normal   Killing    40s    kubelet            Stopping container app
```
User (India)
   |
   | long-distance request
   v
Origin Server (USA)
   |
   | long-distance response
   v
User