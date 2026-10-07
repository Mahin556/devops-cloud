  ```yaml
  apiVersion: v1  # Specifies the API version used to create the Pod.
  kind: Pod       # Declares the resource type as a Pod.
  metadata:
    name: emptydir-example  # Name of the Pod.
  spec:
    containers:
    - name: busybox-container  # Name of the container inside the Pod.
      image: busybox           # Using the lightweight BusyBox image.
      command: ["/bin/sh", "-c", "sleep 3600"]  # Overrides the default command. Keeps the container running for 1 hour (3600 seconds).
      volumeMounts:
      - mountPath: /data       # Mount point inside the container where the volume will be accessible.
        name: temp-storage     # Refers to the volume defined in the `volumes` section below.
    - name: busybox-container-2  # Name of the container inside the Pod.
      image: busybox           # Using the lightweight BusyBox image.
      command: ["/bin/sh", "-c", "sleep 3600"]
      volumeMounts:
      - mountPath: /data
        name: temp-storage
    volumes:
    - name: temp-storage       # Name of the volume, must match the name in `volumeMounts`.
      emptyDir: {}             # Creates a temporary directory that lives as long as the Pod exists.
                              # Useful for storing transient data that doesn't need to persist.

  ```
  *Here, `/data` is an emptyDir volume that will be removed along with the Pod.*

  ```bash
  kubectl apply -f emptydir-example.yaml
  ```
  ```bash
  kubectl exec emptydir-example -c busybox-container -- sh -c 'echo "What a file!" > /data/myfile.txt'
  ```
  ```bash
  kubectl exec emptydir-example -c busybox-container-2 -- cat /data/myfile.txt
  ```
  ```
  What a file!
  ```
  ```bash
  ssh node01

  node01:~$ crictl ps
    CONTAINER           IMAGE               CREATED             STATE               NAME                  ATTEMPT             POD ID              POD                        NAMESPACE
    e630950cd27ed       08ef35a1c3f05       50 seconds ago      Running             busybox-container-2   0                   8e11541f662f7       emptydir-example           default
    cd3ac827e0f3e       08ef35a1c3f05       51 seconds ago      Running             busybox-container     0                   8e11541f662f7       emptydir-example           default
    af0da552dd4d4       52546a367cc9e       10 minutes ago      Running             coredns               1                   6ee72e9892472       coredns-76bb9b6fb5-4z2mz   kube-system
    d2af2863f6b20       52546a367cc9e       10 minutes ago      Running             coredns               1                   1887b08aafb0b       coredns-76bb9b6fb5-7vqcc   kube-system
    97b6dc83ec59a       e6ea68648f0cd       10 minutes ago      Running             kube-flannel          1                   01155d711b5f4       canal-kc8m5                kube-system
    4d99e6daea095       75392e3500e36       10 minutes ago      Running             calico-node           1                   01155d711b5f4       canal-kc8m5                kube-system
    b1001781f396e       fc25172553d79       11 minutes ago      Running             kube-proxy            1                   8b504e477aaeb       kube-proxy-kgl6s           kube-system

  node01:~$ ls /var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/
    myfile.txt

  node01:~$ cat /var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/myfile.txt 
    What a file!
  ```
  ```bash
  controlplane:~$ kubectl delete pod emptydir-example
    pod "emptydir-example" deleted from default namespace

  node01:~$ ls /var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/
    ls: cannot access '/var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/': No such file or directory
  
  node01:~$ cat /var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/myfile.txt 
    cat: /var/lib/kubelet/pods/74d5370f-076d-4829-b1e2-a99d4093d8a7/volumes/kubernetes.io~empty-dir/temp-storage/myfile.txt: No such file or directory
  ```