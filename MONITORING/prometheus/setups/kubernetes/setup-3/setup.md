This is an excellent, hands-on walkthrough from Abhishek’s DevOps course (Day 42). Below is a **detailed, structured guide** based on his transcript, covering the "Why," the Architecture, and the Step-by-Step implementation of monitoring a Minikube cluster using Prometheus and Grafana.

---

# Day 42: Kubernetes Monitoring with Prometheus & Grafana

In this guide, we will set up a complete monitoring stack for a Kubernetes cluster. We will install Prometheus (for metrics collection) and Grafana (for visualization) using Helm, explore the default metrics, and finally look at how to scrape custom metrics (like `kube-state-metrics`).

---

## 1. Why Do We Need Monitoring?

If you have a single cluster managed by one person, manual checks might suffice. However, in real-world scenarios:
- **Multiple Teams** use the same cluster.
- **Multiple Environments** exist (Dev, Staging, Prod).
- **Complex Deployments** make it hard to manually track if a service is down or if replicas are mismatched.

**Monitoring provides:**
- **Visibility** into cluster health (API server, nodes, pods).
- **Proactive Alerts** (via AlertManager) before users are impacted.
- **Historical Data** to analyze performance trends.

---

## 2. What are Prometheus and Grafana?

| Tool | Purpose |
| :--- | :--- |
| **Prometheus** | An open-source monitoring toolkit that scrapes metrics from targets (like Kubernetes API) and stores them in a **Time Series Database (TSDB)**. |
| **Grafana** | A data visualization platform. It uses Prometheus as a **Data Source** to query metrics and display them as beautiful, interactive dashboards. |

---

## 3. Prometheus High-Level Architecture (Simplified)

Based on the transcript, here is how the components interact:

1. **Prometheus Server**: The core component.
   - Contains a **Time Series Database (TSDB)** to store metrics on disk.
   - Contains an **HTTP Server** to accept queries (PromQL).
2. **Targets**: Prometheus scrapes metrics from:
   - **Kubernetes API Server** (exposes default metrics like node status).
   - **kube-state-metrics** (exposes detailed object states like deployment replicas).
   - **Custom Application Metrics** (exposed by developers using Prometheus client libraries).
3. **AlertManager**: Receives alerts from Prometheus and sends notifications to Slack, Email, etc. (Mentioned in architecture, though not fully demoed in this specific walkthrough).
4. **Visualization (Grafana)**: Queries Prometheus via its API to render graphs.

---

## 4. Hands-On Lab: Setup on Minikube

### Prerequisites
- A running Kubernetes cluster (Minikube is used here).
- `kubectl` and `helm` installed.

**Step 1: Start Minikube**
To avoid networking issues, use a specific driver:
```bash
minikube start --memory=4096 --driver=hyperkit
# Or use virtualbox if on Windows/Linux
```
*Verify:*
```bash
kubectl get pods -A
```

---

## 5. Installing Prometheus using Helm

We will use the Prometheus Community Helm Chart.

**Step 1: Add the Helm Repo**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update  # Always update to get the latest version
```

**Step 2: Install Prometheus**
```bash
helm install prometheus prometheus-community/prometheus
```
*Wait a minute for the pods to spin up.*
```bash
kubectl get pods
# Expected: prometheus-server, alertmanager, kube-state-metrics, node-exporters
```

**Step 3: Expose Prometheus UI (NodePort)**
By default, the service is `ClusterIP`. To access the UI, expose it as a NodePort:
```bash
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-ext
```
Get the Minikube IP and the NodePort:
```bash
minikube ip
kubectl get svc prometheus-server-ext
```
*Access the UI:* `http://<minikube-ip>:<node-port>`

---

## 6. Installing Grafana using Helm

**Step 1: Add the Grafana Repo & Install**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana
```

**Step 2: Get the Admin Password**
Grafana generates a random password. Retrieve it:
```bash
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

**Step 3: Expose Grafana UI (NodePort)**
```bash
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-ext
```
*Access the UI:* `http://<minikube-ip>:<node-port>` (Username: `admin`, Password: *from step 2*).

---

## 7. Configuring Grafana (Data Source & Dashboard)

### 7.1 Add Prometheus as a Data Source
1. Log in to Grafana.
2. Go to **Configuration (Gear icon) > Data Sources > Add data source**.
3. Select **Prometheus**.
4. Set the **URL** to: `http://<minikube-ip>:<node-port-of-prometheus>` (e.g., `http://192.168.64.15:31110`).
5. Click **Save & Test** (You should see "Data source is working").

### 7.2 Import a Pre-Made Dashboard (ID: 3662)
Instead of building a dashboard from scratch, import a community template.
1. Hover over the **+** icon (Create) and select **Import**.
2. Enter Dashboard ID: **3662** *(Note: The speaker initially says 3326 but corrects it to 3662)*.
3. Click **Load**.
4. Select the Prometheus data source you just created.
5. Click **Import**.

*Voilà!* You now have a comprehensive dashboard showing Kubernetes API server metrics, node status, memory usage, and more.

---

## 8. Deep Dive: What is `kube-state-metrics`?

**Why is it required?**
The standard Kubernetes API server only exposes basic metrics (e.g., node CPU). However, it **does not** expose metrics about object states (e.g., "Is my Deployment stuck?" or "Are the replica counts matching?").

**What does it do?**
`kube-state-metrics` is a service that listens to the Kubernetes API and generates metrics about the *state* of objects like:
- Deployments (desired replicas vs. available replicas).
- Pods (status phases: Pending, Running, Failed).
- Jobs and CronJobs.

**How to see its raw metrics?**
When you installed Prometheus via Helm, `kube-state-metrics` was installed automatically. To view its raw output:
```bash
# Expose the kube-state-metrics service
kubectl expose service prometheus-kube-state-metrics --type=NodePort --target-port=8080 --name=ksm-ext
```
Visiting the NodePort in your browser will show a massive list of metrics like:
```
kube_deployment_status_replicas_available{deployment="my-app"} 3
kube_pod_status_phase{namespace="default", phase="Running"} 5
```

---

## 9. How to Add Custom Scrape Targets (Editing the ConfigMap)

If you want Prometheus to scrape metrics from a specific endpoint (e.g., a custom application or the newly exposed `kube-state-metrics` endpoint), you must edit the Prometheus ConfigMap.

**Step 1: Edit the ConfigMap**
```bash
kubectl edit cm prometheus-server
```

**Step 2: Add a new scrape job**
Look for the `scrape_configs` section and add a new job. For example, to scrape the raw `kube-state-metrics` endpoint (though it is already scraped internally, this demonstrates the concept):

```yaml
scrape_configs:
  # ... existing default configs ...

  # New custom job
  - job_name: 'custom-ksm'
    static_configs:
      - targets: ['<minikube-ip>:<ksm-node-port>']
```

**Step 3: Restart Prometheus**
After saving, restart the Prometheus pod for the changes to take effect:
```bash
kubectl delete pod prometheus-server-xxxxxxxxxx-xxxxx
```
*(The ReplicaSet will automatically bring up a new pod with the updated config).*

---

## 10. Key Takeaway for Custom Applications

While `kube-state-metrics` gives you cluster object info, **it does NOT give you application-level metrics** (e.g., "How many HTTP 500 errors does my app have?").

- **To monitor your own apps**, your developers must expose a `/metrics` endpoint using **Prometheus Client Libraries** (available for Go, Java, Python, Node.js, etc.).
- Once the app is deployed and exposes the endpoint, you simply add a new scrape job in the Prometheus ConfigMap (as shown in Section 9) pointing to your application's service.

---

## Summary of Commands Cheat Sheet

```bash
# 1. Start Minikube
minikube start --memory=4096

# 2. Add Repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Install Prometheus & Grafana
helm install prometheus prometheus-community/prometheus
helm install grafana grafana/grafana

# 4. Get Grafana Password
kubectl get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# 5. Expose Services
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-ext
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-ext

# 6. Check Services
kubectl get svc
```

---

## Conclusion

In this session, you learned:
1. **Why monitoring is essential** for distributed systems.
2. The **core architecture** of Prometheus (TSDB, Server, Targets).
3. How to **install the stack** using Helm.
4. How to **visualize data** using Grafana's pre-built dashboards.
5. How **kube-state-metrics** bridges the gap for object-level monitoring.

**Next Steps:** Explore writing PromQL queries, setting up AlertManager for Slack/Email alerts, and instrumenting your custom applications with Prometheus client libraries.