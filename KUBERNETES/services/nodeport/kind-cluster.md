# **Setting Up a KIND Cluster with NodePort Service**  

In this guide, we will set up a **Kubernetes cluster using KIND (Kubernetes IN Docker)** and configure it to allow external access to a **NodePort service**.  


## **Step 1: Check Existing KIND Clusters**
Before creating a new KIND cluster, check if any existing clusters are running:  
```sh
kind get clusters
```
This command lists all existing KIND clusters.  

## **Step 2: Delete the Existing Cluster (If Any)**
To ensure a clean setup, delete the existing KIND cluster before proceeding:  
```sh
kind delete cluster --name my-first-cluster
```
This removes the old cluster (`my-first-cluster`) and frees up resources.  

## **Step 3: Create a New KIND Cluster**
### **3.1 Use the Below Configuration File (`kind-cluster.yaml`)**

```sh
kind create cluster --name my-second-cluster --config kind-cluster.yaml
```

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

# Specify the Kubernetes version by using a specific node image
# Visit https://hub.docker.com/r/kindest/node/tags and https://github.com/kubernetes-sigs/kind/releases for available images

nodes:
  - role: control-plane
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30 # Replace with the Kubernetes version you want
    extraPortMappings:
      - containerPort: 31000 # Port inside the KIND container
        hostPort: 31000 # Port on your local machine (host system). 
        # If this were set to 9090, you would access the service at localhost:9090, 
        # and traffic would be forwarded to containerPort 31000 inside the KIND cluster.
  - role: worker
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
  - role: worker
    image: kindest/node:v1.31.4@sha256:2cb39f7295fe7eafee0842b1052a599a4fb0f8bcf3f83d96c7f4864c357c6c30
```

### **Create the Cluster Using This Configuration**
Run the following command to create a new KIND cluster using the configuration file:  
```sh
kind create cluster --name my-second-cluster --config kind-cluster.yaml
```

This creates a **three-node cluster** with one control plane node and two worker nodes. The **extraPortMappings** section allows **NodePort services** to be accessed from the host machine.  

## **Understanding `extraPortMappings` Configuration**

![Alt text](/images/12f.png)
```yaml
extraPortMappings:
  - containerPort: 31000
    hostPort: 31000
```
### **Breakdown of Each Field**
- **containerPort:** The port inside the KIND container that will receive traffic.  
- **hostPort:** The port on your local machine (host system) that will be mapped to the `containerPort`.   

### **Example Use Case**
If `containerPort: 31000` is mapped to `hostPort: 31000`, then:  
- A Kubernetes **NodePort service** running inside the cluster on port **30950** will be accessible from the **host machine** at:  
  ```sh
  curl http://127.0.0.1:30950
  ```
- Traffic will be **forwarded from the host machine to the KIND cluster**, allowing easy access to services running inside the cluster.  

This setup enables **exposing Kubernetes services using NodePort** while ensuring they are accessible from the **local machine** without needing complex networking configurations.
