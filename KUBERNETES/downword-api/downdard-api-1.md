- A way for Kubernetes to expose Pod and container information(field) to the containers themselves.
- No kube-apiserver involvment.
- Provides Pod-level and Container-level metadata.
- Two ways
    - Environment variables (env → valueFrom)
    - Volume files (downwardAPI volume)

### Exposing Pod fields as environment variables
- You can inject values from Pod metadata and status into container environment variables.
```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dapi-envars-fieldref
spec:
  containers:
    - name: test-container
      image: registry.k8s.io/busybox:1.27.2
      command: [ "sh", "-c"]
      args:
      - while true; do
          echo -en '\n';
          printenv MY_NODE_NAME MY_POD_NAME MY_POD_NAMESPACE;
          printenv MY_POD_IP MY_POD_SERVICE_ACCOUNT;
          sleep 10;
        done;
      env:
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: MY_POD_SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
  restartPolicy: Never
EOF
```
What happens here:
    MY_NODE_NAME → Name of the node where Pod runs
    MY_POD_NAME → Pod’s name
    MY_POD_NAMESPACE → Namespace of the Pod
    MY_POD_IP → Pod IP address
    MY_POD_SERVICE_ACCOUNT → ServiceAccount name

```bash
kubectl logs dapi-envars-fieldref
```
Example output:
```bash
minikube
dapi-envars-fieldref
default
172.17.0.4
default
```

### Exposing Container fields as environment variables
- You can also expose container resource requests and limits via resourceFieldRef.
```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dapi-envars-resourcefieldref
spec:
  containers:
    - name: test-container
      image: registry.k8s.io/busybox:1.27.2
      command: [ "sh", "-c"]
      args:
      - while true; do
          echo -en '\n';
          printenv MY_CPU_REQUEST MY_CPU_LIMIT;
          printenv MY_MEM_REQUEST MY_MEM_LIMIT;
          sleep 10;
        done;
      resources:
        requests:
          memory: "32Mi"
          cpu: "125m"
        limits:
          memory: "64Mi"
          cpu: "250m"
      env:
        - name: MY_CPU_REQUEST
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: requests.cpu
        - name: MY_CPU_LIMIT
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: limits.cpu
        - name: MY_MEM_REQUEST
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: requests.memory
        - name: MY_MEM_LIMIT
          valueFrom:
            resourceFieldRef:
              containerName: test-container
              resource: limits.memory
  restartPolicy: Never
EOF
```
What happens here:
    MY_CPU_REQUEST → CPU request (125m)
    MY_CPU_LIMIT → CPU limit (250m)
    MY_MEM_REQUEST → Memory request (32Mi = 33554432 bytes)
    MY_MEM_LIMIT → Memory limit (64Mi = 67108864 bytes)

```bash
kubectl logs dapi-envars-resourcefieldref
```
Example output:
```bash
125m
250m
33554432
67108864
```


