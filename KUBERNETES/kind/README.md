### References:-
- [Day 8: Setting Up Kind Cluster Locally & Kubernetes Context](https://youtu.be/wBF3YCMgZ7U)

---

### Additional Resources:
- For the official list of resources, refer to the [Certification Resources Allowed](https://docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed#certified-kubernetes-administrator-cka-and-certified-kubernetes-application-developer-ckad). 

---

### Important Installation links:
* [Home](https://kind.sigs.k8s.io/)
* [Kubectl Installation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [Kind Installation](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* [Release notes](https://github.com/kubernetes-sigs/kind/releases)
* [Cluster creation](https://kind.sigs.k8s.io/docs/user/quick-start/#creating-a-cluster)

---

```bash
controlplane:~$ kubectl version
Client Version: v1.33.2
Kustomize Version: v5.6.0
Server Version: v1.33.2
controlplane:~$ kubectl version --client
Client Version: v1.33.2
Kustomize Version: v5.6.0

kubectl cluster-info --context kind-kind
kubectl cluster-info --context kind-kind-2
```

```bash
kind create cluster --help
```
---

### First Scenario: *my-first-cluster*

  ```yaml
  # kind-cluster-config.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4

  # Specify the Kubernetes version by using a specific node image
  # Visit https://hub.docker.com/r/kindest/node/tags and https://github.com/kubernetes-sigs/kind/releases for available images
  nodes:
    - role: control-plane
      image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30 # Replace with the Kubernetes version you want
    - role: worker
      image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
    - role: worker
      image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
  ```

  ```yaml
  # kind-multinode.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
    image: kindest/node:v1.29.0@sha256:4c022f4e737f2bff203f94a7c540b9ae339bd4168d7ce74d4df38a2c8ff5c5f2
  - role: worker
    image: kindest/node:v1.29.0@sha256:4c022f4e737f2bff203f94a7c540b9ae339bd4168d7ce74d4df38a2c8ff5c5f2
  - role: worker
    image: kindest/node:v1.29.0@sha256:4c022f4e737f2bff203f94a7c540b9ae339bd4168d7ce74d4df38a2c8ff5c5f2
  ```

  ```bash
  kind create cluster --name my-first-cluster --config kind-cluster.yaml
  ```
  ```bash
  kind create cluster --name mycluster --config kind-multinode.yaml --wait 2m
  ```
  * Waiting for cluster readiness
    * By default, the command finishes before the cluster is fully ready.
    * To block until control plane is ready, use `--wait <time>`:
        ```bash
        --wait 30s → wait 30 seconds
        --wait 5m → wait 5 minutes
        ```
  * Runtime providers
    * kind auto-detects container runtimes (Docker, Podman, nerdctl).
    * To force a specific one, set environment variables:
        ```bash
        KIND_EXPERIMENTAL_PROVIDER=docker
        KIND_EXPERIMENTAL_PROVIDER=podman
        KIND_EXPERIMENTAL_PROVIDER=nerdctl
        ```

  ```bash
  kind get clusters
  ```
  ```bash
  kubectl get nodes -o wide
  ```
  * A **configuration file** was used to define the cluster setup, including:
    - **Image Version** 
    - **Number of Nodes**
  
- Using configuration files is generally preferred because:
  - **Version control**-> Track changes and rollback when thing get wrong.
  - **Declarative practices**-> visibale, sharable, regenerate.
  - Configuration files can be **Shared across teams**, promoting collaboration and standardization.
  - **Single source of truth** for cluster configurations, reducing the risk of discrepancies or errors during manual setup.
  - Written in YAML(Easy to read/use human/admins/devops) just like other toole like Terraform, Ansible, Helm, Kubernetes and other DevOps Tools which heavily rely on manifest or configuration files to define infrastructure and deployments in YAML.


---

### Second Scenario: *my-second-cluster*
- The cluster was created using the following command:
  ```bash
  kind create cluster --name my-second-cluster
  ```
  Instead of relying on a configuration file, we directly ran the command, which:
  - Defaulted to the **latest image**.
  - Could have been customized by specifying an image using the `--image` flag.

- While quicker for simple setups, this approach lacks:
  - The **versioning benefits** provided by configuration files.
  - The **declarative advantages**, such as reproducibility and maintainability.

---

### Important Note About Naming in Kind
- **Kind** assigns the **same name** to the user and context as the cluster name, which might seem confusing at times. 
- In production environments, these names are typically **distinct** to avoid confusion(kubeadm).

---

### Managing Kubernetes Contexts for Multiple Clusters

* **Kubernetes contexts** allow users to easily manage multiple clusters and namespaces by storing cluster, user, and namespace information in the `kubeconfig` file. 
* Each context defines a combination of a cluster, a user, and a namespace, making it simple for users like `Varun` to switch between clusters and namespaces seamlessly without manually changing the configuration each time.

#### Scenario:

![Alt text](/images/8a.png)

Varun, the user, wants to access three different Kubernetes clusters from his laptop. Let's assume these clusters are:
1. **Cluster 1** (for development)
2. **Cluster 2** (for staging)
3. **Cluster 3** (for production)

Varun will need to interact with these clusters frequently. Using Kubernetes contexts, he can set up and switch between these clusters easily.

#### How Kubernetes Contexts Work:

##### 1. Configuring Contexts:
* In the `kubeconfig` file, each cluster, user, and namespace combination is stored as a context. So, Varun can have three different contexts, one for each cluster. The contexts will contain:
  - **Cluster details**: API server URL, certificate authority, etc.
  - **User details**: Authentication method (e.g., username/password, token, certificate).
  - **Namespace details**: The default namespace to work in for the context (though the namespace can be overridden on a per-command basis).

##### 2. Switching Between Contexts:
* With Kubernetes contexts configured, Varun can easily switch between them. If he needs to work on **Cluster 1**, he can switch to the `dev-context`. Similarly, for **Cluster 2**, he switches to `staging-context`, and for **Cluster 3**, the `prod-context`.
* A **Kubernetes namespace** is a virtual cluster within a physical cluster that provides logical segregation for resources, enabling multiple environments (e.g., dev, staging, prod) to coexist on the same cluster. 
* For example, in a cluster running multiple applications, each application can run in its own namespace, ensuring isolation and avoiding conflicts between resources like services or pods.
* I’ve included the namespace section here for completeness. We’ll dive deeper into working with namespaces later in the course.

##### Example `kubeconfig` File:

```bash
kubectl config view #safe way to view config file instead directly opening a file
```

```yaml
apiVersion: v1
clusters:
- name: cluster-1
  cluster:
    server: https://cluster-1-api-server
    certificate-authority-data: <certificate-data>
- name: cluster-2
  cluster:
    server: https://cluster-2-api-server
    certificate-authority-data: <certificate-data>
- name: cluster-3
  cluster:
    server: https://cluster-3-api-server
    certificate-authority-data: <certificate-data>
users:
- name: varun-user
  user:
    client-certificate-data: <client-cert-data>
    client-key-data: <client-key-data>
contexts:
- name: dev-context
  context:
    cluster: cluster-1
    user: varun-user
    namespace: dev
- name: staging-context
  context:
    cluster: cluster-2
    user: varun-user
    namespace: staging
- name: prod-context
  context:
    cluster: cluster-3
    user: varun-user
    namespace: prod
current-context: dev-context
```

* By default, the kubeconfig file is written to:
```bash
${HOME}/.kube/config
```
* We can set the `kubeconfig.yaml` file in `KUBECONFIG` ENV
  * If `$KUBECONFIG` environment variable is set, it’s treated as a **list of paths** (separated by `:` on Linux/macOS or `;` on Windows).
  * Values are **merged** from all listed paths.
  * If a value is modified → it updates the file where it originally came from.
  * If a new value is added → it goes into the **first file** that exists.
  * If none exist → it creates the **last file** in the list.

<br>

* You can control where the cluster configuration is written with:
  ```bash
  kind create cluster --kubeconfig=myconfig.yaml
  ```
  * Only `myconfig.yaml` is used.
  * No merging occurs.
  * The flag can only be set **once**.

**Switch Contexts Easily:**
```bash
kubectl config use-context <context-name>
```
```Bash
kubectl config use-context dev-context    # Switch to Cluster 1
kubectl config use-context staging-context # Switch to Cluster 2
kubectl config use-context prod-context   # Switch to Cluster 3
```

**Namespace Management:**

When Varun switches contexts, he can also set the default namespace. For example, when switching to prod-context, the default namespace would be prod. However, he can override this on the command line if needed:

```Bash
kubectl get pods --namespace=dev  # Override the default namespace for a command
```

**Setting a Default Namespace with `kubectl config`**

```bash
kubectl config set-context --current --namespace=app1-ns
```
```Bash
kubectl config current-context
```
**To list all contexts:**
```bash
kubectl config get-contexts
```

**Efficient Cluster Management:**
  * Using it we can point `kubectl` to a specific cluster with user and namespace.
  * Prevent  manually specify the cluster or user details every time.


#### Kubernetes Origin
![Alt text](/images/8b.png)

---

### Build and Load a Custom Image

```dockerfile
# Dockerfile
FROM nginx:alpine
RUN echo '<h1>Hello from Kind Cluster!</h1>' > /usr/share/nginx/html/index.html
```
```bash
docker build -t my-nginx:demo .
```
Load the image into kind:
```bash
kind load docker-image my-nginx:demo --name mycluster
```
Verify image is present on a node:
```bash
docker exec -it mycluster-control-plane crictl images | grep my-nginx
```
Deploy a Pod Using That Image
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-nginx
  template:
    metadata:
      labels:
        app: my-nginx
    spec:
      containers:
      - name: nginx
        image: my-nginx:demo
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
```
```bash
kubectl apply -f nginx-deploy.yaml
```
```bash
kubectl expose deployment my-nginx --type=NodePort --port=80
```
```bash
kubectl get svc my-nginx
```
Port-forward (easier for local testing):
```bash
kubectl port-forward svc/my-nginx 8080:80
```
Now open [http://localhost:8080](http://localhost:8080) → you should see **“Hello from Kind Cluster!”** 🎉

Delete the cluster:
```bash
kind delete cluster --name mycluster
```

---

### Cluster configs

* **Pass a custom config file**
  ```bash
  kind create cluster --config kind-example-config.yaml
  ```

---

* **Multi-node cluster (1 control-plane + 2 workers)**
  ```yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
  - role: worker
  - role: worker
  ```

  * Multi-node cluster with labels
    ```yaml
    # multinode.yaml
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
    - role: control-plane
    - role: worker
      labels:
        tier: frontend
    - role: worker
      labels:
        tier: backend
    ```
  ```bash
  kind create cluster --config multinode.yaml
  kubectl get nodes --show-labels
  ```


---

* **HA cluster (3 control-plane + 3 workers)**
  ```yaml
  nodes:
  - role: control-plane
  - role: control-plane
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
  ```

---

* **Expose a port from cluster to host (map node port 80 to host port 80)**
  ```yaml
  nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      listenAddress: "0.0.0.0"
      protocol: udp
  ```
  ```yaml
  # port-mapping.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
    extraPortMappings:
    - containerPort: 30950
      hostPort: 8080
  ```
  Deploy a NodePort service:
  ```yaml
  apiVersion: v1
  kind: Pod
  metadata:
    name: echo
    labels:
      app: echo
  spec:
    containers:
    - name: echo
      image: hashicorp/http-echo:0.2.3
      args: ["-text=Hello from kind!"]
      ports:
      - containerPort: 5678
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: echo
  spec:
    type: NodePort
    selector:
      app: echo
    ports:
    - port: 5678
      nodePort: 30950
  ```
  ```bash
  kubectl apply -f echo.yaml
  curl http://127.0.0.1:8080
  ```

---

* **Set Kubernetes version explicitly by node image**
  ```bash
  nodes:
  - role: control-plane
    image: kindest/node:v1.16.4@sha256:<sha256sum>
  - role: worker
    image: kindest/node:v1.16.4@sha256:<sha256sum>
  ```

---

* **Enable feature gates**
  ```yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  featureGates:
    FeatureGateName: true
  ```
  ```yaml
  # feature-gates.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  featureGates:
    "CSIMigration": true
  ```
  ```bash
  kind create cluster --config feature-gates.yaml
  kubectl get nodes -o wide
  ```

---

* **Proxy Settings**
  * Environment variables supported
    ```bash
    HTTP_PROXY / http_proxy
    HTTPS_PROXY / https_proxy
    NO_PROXY / no_proxy
    • kind appends internal Kubernetes addresses to NO_PROXY automatically.
    ```

---

* **Exporting Cluster Logs(Export logs from default cluster)**
  ```bash
  kind export logs
  ```
  --> Saves to /tmp/<random_id>

---

* **Export logs to a specific directory**
  ```bash
  kind export logs ./somedir
  ```
  Logs include:
      Docker info
      Node logs (journal, kubelet, pods, etc.)
      Kubernetes version info

---

* **Custom networking**
  ```yaml
  # networking.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  networking:
    ipFamily: dual
    podSubnet: "10.244.0.0/16"
    serviceSubnet: "10.96.0.0/12"
    kubeProxyMode: "ipvs"
  ```
  ```bash
  kind create cluster --config networking.yaml
  kubectl get pods -A -o wide
  ```
  * `ipFamily: ipv4 | ipv6 | dual`
  * `apiServerAddress`, `apiServerPort`
  * `podSubnet`, `serviceSubnet`
  * `disableDefaultCNI: true` → for using Calico, Cilium, etc.
  * `kubeProxyMode: iptables | ipvs | nftables | none`

---

* **Nodes**

  * `role: control-plane | worker`
  * `image: kindest/node:<k8s-version>@sha256:...`
  * `extraMounts` → map host directories into nodes
  * `extraPortMappings` → expose node ports to host
  * `labels` → useful for scheduling
  * `kubeadmConfigPatches` → advanced customization of kubeadm

---

* **Create a named cluster**
  ```yaml
  # cluster-name.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  name: demo-cluster
  ```
  ```bash
  kind create cluster --config cluster-name.yaml
  kind get clusters
  ```
  * `runtimeConfig` → enable/disable alpha/beta APIs

---

* **Advanced kubeadm patches**
  ```yaml
  # kubeadm-patch.yaml
  kind: Cluster
  apiVersion: kind.x-k8s.io/v1alpha4
  nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "special=true"
  ```
  ```bash
  kind create cluster --config kubeadm-patch.yaml
  kubectl get nodes --show-labels
  ```

