- **Observability**
- **Prometheus** 
- **Grafana**

## What is Observability?

Observability is made up of three important things:

1. **Monitoring** – Your applications, once deployed, need to be monitored.
2. **Logging** – Collecting logs from those applications.
3. **Tracing** – Tracking requests to debug issues.

Additionally, there is **Alerting** – if your application fails, alerts should be triggered.

### How Are These Different?

- **Monitoring**: You need to know the metrics of your application (CPU, memory, network, etc.).
- **Logging**: For example, if your sign-in fails or a service throws an error, logs help you understand what's happening.
- **Tracing**: If you encounter an error, tracing helps you figure out how you reached that error and how to resolve it.
- **Alerting**: If your CPU percentage goes above 70% or 90%, you receive an email alert.

When you put all this into **visualization**, dashboards are created. For example, here we can see CPU, memory, network, and everything graphically.

- For **monitoring metrics and tracing**, you use **Prometheus**.
- For **visualization** and creating dashboards, you use **Grafana**.

---

## Deploying the Application

I've put the entire application in a **GitHub repository**. You'll find the link in the description. It contains everything—how to create dashboards, how to set up Prometheus, etc.

First, let's clone the repository:

```bash
git clone https://github.com/Mahin556/k8s-kind-voting-app.git
cd k8s-kind-voting-app
```

Now, let's set up our server:

```bash
sudo apt-get update
sudo apt-get install docker.io -y
```

### Why Docker?

Because our Kubernetes cluster is a **Kind cluster** (Kubernetes in Docker). You can run it on your local system too, but I'm using AWS so that everyone in India can follow along with the same setup and errors.

### Fix Docker Permissions

```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps  # Should work now
```

---

## Setting Up the Kind Cluster

I've written a Kind cluster configuration with **one control plane** and **two worker nodes**. Let's install Kind:

```bash
chmod +x install-kind
./install-kind
```

Now create the cluster:

```bash
kind create cluster --name mycluster --config kind-config.yaml
```

### What is ArgoCD?

ArgoCD is a simple tool that takes code from GitHub (Kubernetes manifests) and deploys them to your cluster in a **GitOps** way. GitOps means all operations and updates happen through Git—no separate CI/CD pipelines needed.

### Install kubectl

```bash
chmod +x install-kubectl
./install-kubectl
kubectl get nodes
```

You should see your control plane and worker nodes.

---

## Deploying the Voting Application

There are two ways to deploy:
1. Using **ArgoCD** (explained in the previous video)
2. Directly using **kubectl apply**

I'll use the second method:

```bash
kubectl apply -f .  # Applies all manifests
```

Check the status:

```bash
kubectl get all
```

All pods, services, and deployments should be running.

### Port Conflict Fix

Our Grafana server runs on port `31000` by default, and the voting service also uses the same port. To avoid conflicts, I changed the voting service port to `31000` in the manifest. I've already pulled those changes from Git.

---

## What is Prometheus?

**Prometheus** is basically a **Time Series Database**.

Imagine you want to create a graph where:
- X-axis = Time
- Y-axis = CPU Percentage

Prometheus stores data like:
- At 5 minutes: CPU = 20%
- At 10 minutes: CPU = 40%
- At 15 minutes: CPU = 60%

Prometheus has:
- A **scraping server** that collects data from your cluster
- A **query server** that lets you query the stored data

---

## Installing Prometheus & Grafana Using Helm

Manually creating all the manifests for Prometheus and Grafana would take too long. So we use **Helm**—a package manager for Kubernetes.

### What is Helm?

**Helm** is a package manager for Kubernetes manifests. You can install, manage, delete, and upgrade applications with one command.

### Install Helm

I've already put the installation commands in the `commands.md` file:

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh
helm version  # Verify installation
```

### Add Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add stable https://charts.helm.sh/stable
helm repo update
```

### Create a Namespace

```bash
kubectl create namespace monitoring
```

### Install the Prometheus Stack

Here's the single command that installs everything:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30000 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=31000 \
  --set alertmanager.service.type=NodePort \
  --set alertmanager.service.nodePort=32000
```

This installs:
- **Prometheus** (port 30000)
- **Grafana** (port 31000)
- **AlertManager** (port 32000)
- **Node Exporter** (collects node metrics)

### Verify Installation

```bash
kubectl get pods -n monitoring
```

You should see:
- Prometheus pods
- Grafana pods
- AlertManager pods
- Node Exporter pods

All should be **Running**.

---

## Accessing Prometheus

Prometheus runs on port `30000` externally, but internally it uses port `9090`. We need to port-forward:

```bash
kubectl port-forward -n monitoring service/prometheus-kube-prometheus-prometheus 9090:9090 --address 0.0.0.0
```

Now open your browser and go to: `http://<public-ip>:9090`

You'll see the Prometheus UI!

### Check Targets

Go to **Status > Targets**. You'll see all targets are UP and scraping metrics.

### Query Metrics

Prometheus uses **PromQL** (Prometheus Query Language).

Example queries:
- Container CPU usage:  
  `sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m]))`
- Network receive bytes:  
  `sum(rate(container_network_receive_bytes_total{namespace="default"}[5m]))`

You can execute these and see graphs.

---

## Accessing the Voting App

To generate traffic and see metrics in real-time:

```bash
kubectl port-forward -n default service/vote 5000:5000 --address 0.0.0.0
```

Now go to: `http://<public-ip>:5000`

Vote repeatedly to generate traffic. Watch the Prometheus graphs spike!

---

## Accessing Grafana

Grafana runs on port `31000`, but internally it uses port `3000`:

```bash
kubectl port-forward -n monitoring service/prometheus-grafana 3000:3000 --address 0.0.0.0
```

Open: `http://<public-ip>:3000`

- **Username:** `admin`
- **Password:** `prom-operator` (default)

### Grafana UI Overview

Grafana has two main concepts:
1. **Data Sources** – Where your metrics come from (e.g., Prometheus)
2. **Dashboards** – Where you visualize your data

### Add a Data Source

Go to **Administration > Data Sources**. You'll see Prometheus is already added because we used the Helm chart.

### Create a Dashboard

1. Go to **Dashboards > New Dashboard > Add Visualization**
2. Select the **Prometheus** data source
3. Write a PromQL query, e.g., `container_cpu_usage_seconds_total`
4. Choose visualization type (graph, bar chart, etc.)
5. Click **Apply** and **Save**

### User Management

You can create new users:
1. Go to **Administration > Users**
2. Click **New User**
3. Enter details and create
4. Assign roles: **Viewer**, **Editor**, or **Admin**

Now you can share the login with your team!

---

## Importing a Pre-Built Kubernetes Dashboard

Instead of building from scratch, you can import community dashboards:

1. Search for **"Grafana Kubernetes dashboard"** on Google
2. Pick one you like (e.g., with ID `315`)
3. Copy the **Dashboard ID**
4. In Grafana, go to **+ > Import**
5. Paste the ID and click **Load**
6. Select your Prometheus data source
7. Click **Import**

Within seconds, you'll have a beautiful Kubernetes dashboard showing:
- Node CPU/Memory usage
- Pod status
- Network traffic
- And much more!

---

## Real-Time Demo

Watch how metrics change in real-time:

1. Open the Grafana dashboard
2. Open your voting app in another tab
3. Vote repeatedly
4. See CPU, memory, and network graphs spike instantly

This is the power of **real-time observability**!

---

## Summary

In just about **30 minutes**, we:
- Set up an AWS instance
- Installed Docker and Kind
- Created a Kubernetes cluster
- Deployed a voting application
- Installed Prometheus & Grafana using Helm
- Configured data sources and dashboards
- Monitored real-time metrics

### Key Tools Covered:
- **Kubernetes** – Container orchestration
- **Prometheus** – Time-series metrics collection
- **Grafana** – Visualization and dashboards
- **Helm** – Package manager for Kubernetes
- **ArgoCD** – GitOps continuous delivery

---

## Final Words

I hope this video brought a storm of knowledge to you! If you enjoyed it, let me know in the comments by writing **"JUNOON"** (passion). That will motivate me to bring more amazing projects like this.

Don't forget to:
- **Like** the video
- **Share** with your friends
- **Subscribe** to the channel

Happy Learning! 🚀