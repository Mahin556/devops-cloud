```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myvolumes-pod
spec:
  containers:
  - name: myvolumes-container-1
    image: alpine
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "The Bench Container 1 is Running" ; sleep 3600']
    volumeMounts:
    - name: demo-volume
      mountPath: /demo1   # This container sees the shared volume here

  - name: myvolumes-container-2
    image: alpine
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "The Bench Container 2 is Running" ; sleep 3600']
    volumeMounts:
    - name: demo-volume
      mountPath: /demo2   # This container sees the same shared volume here

  - name: myvolumes-container-3
    image: alpine
    imagePullPolicy: IfNotPresent
    command: ['sh', '-c', 'echo "The Bench Container 3 is Running" ; sleep 3600']
    volumeMounts:
    - name: demo-volume
      mountPath: /demo3   # Same shared volume in another path

  volumes:
  - name: demo-volume
    emptyDir: {}   # Shared ephemeral storage for all containers in this Pod
```