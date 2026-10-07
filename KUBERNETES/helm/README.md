### References:-
- [Day 43: Helm Charts for Beginners | Helm in Kubernetes with 3 Practical Demos](https://www.youtube.com/watch?v=yvV_ZUottOM&ab_channel=CloudWithVarJosh)

---

## Why Helm?

In Kubernetes, as your application evolves from a simple service to a production-grade system, the number of Kubernetes resources grows rapidly. You're not just dealing with a few Deployments anymore — you're managing:

* StatefulSets, ConfigMaps, Secrets
* Ingresses, PVCs, StorageClasses
* Network Policies, Autoscalers
* Even **Custom Resources** (CRs) used by tools like cert-manager, Prometheus, or Vault
* Manual work: 
  * Deploy each manifest.
  * Updated each manifest.
  * Delete each mnifest.
* No centralized place where we can keepa application related info and update on that place can reflect on each resource of application.
* K8S not know appication, k8s know the resource that K8S managing.

Managing these manually across environments becomes increasingly unmanageable.

Even with Kustomize overlays, **you're still dealing with raw YAMLs** that must be copied, patched, and tracked. As application complexity increases, you need a better way to **package, install, upgrade, rollback, and share** your deployments.

• Helm is a package manager for Kubernetes, similar to how **apt** is a package manager for Ubuntu and linux.
* Package manager responsible for installing libraries/binaries/deps in right way and in right place.
* Update application info from center place `values.yaml`.
* Helm install multiple resource, can install dependency charts and provide flexiblity to customize resources.
• Helm simplifies installing, upgrading, and uninstalling Kubernetes applications and controllers
• Kubernetes controllers and tools like **Prometheus, Grafana, Argo CD, NGINX Ingress** can be installed using Helm
• Without Helm, installing applications requires managing many Kubernetes YAML files manually
• Helm bundles all required Kubernetes resources into a single unit called a **chart**
• A **Helm chart** contains deployments, services, config maps, service accounts, and other required resources
• Helm uses **repositories** to store charts, similar to apt repositories in Linux
• Installing an application with Helm usually requires only two steps:
  * Add the Helm repository
  * Run the `helm install` command
• Helm supports full application lifecycle management:
  * Install
  * Upgrade
  * Downgrade
  * Uninstall
• Helm allows installing specific versions of applications (example: Argo CD 2.12 or 2.13)
• Helm reduces operational and maintenance overhead for DevOps teams
• Managing multiple environments (dev, test, UAT, prod) becomes easier with Helm
• Helm avoids writing and maintaining multiple scripts or YAML files for different versions
• Helm automatically manages dependencies required by Kubernetes applications
• Helm ensures Kubernetes resources are created in the correct order
• Helm supports environment-specific configuration using values files
• Helm allows organizations to package their own applications as Helm charts
• Internal teams or external users can install custom applications using Helm
• Helm is inspired by Linux package managers and follows the same concept
• Helm is essential for scalable, maintainable, and professional Kubernetes operations


---

### The Problem

![Alt text](/images/43a.png)

Let’s revisit our example of `app1` deployed in `dev`, `stage`, and `prod`. Each tier (frontend, backend, database) could easily involve 5–6 resources, leading to:

* **15–20 YAMLs per environment**
* **60+ YAMLs across the board**
* And hundreds more when multiple apps and tools come into play

You need to:

* Inject dynamic values (e.g., image tags, port numbers)
* Keep track of what’s deployed where
* Apply upgrades without breaking existing workloads
* Roll back if something goes wrong
* Package and distribute your app in a repeatable format

---

### What Makes Helm Special (Compared to Kustomize)?

In the previous lecture (Day 42), we used **Kustomize** to manage per-environment overlays — like changing image tags, labels, or replica counts between `dev`, `stage`, and `prod`. It lets you organize your manifests and avoid copy-pasting YAMLs.

But **Kustomize stops at configuration management** — it doesn’t handle installation, upgrades, rollbacks, or packaging.

This is where **Helm goes beyond**:

* 🔁 **Templating** using Go templates (`if`, `range`, reusable helpers)
* 📦 **Versioned packaging** of applications into Helm Charts
* 📜 **Release tracking** and **rollback support**
* 🚀 **Install, upgrade, delete** operations via a single command
* 🌍 **Chart repositories** to distribute your application internally or externally
* 🔧 **Hooks and tests** for lifecycle events

Helm is not just about generating YAML — it’s a full **application lifecycle manager** for Kubernetes, much like how `apt` manages software packages on Debian.

![](/images/image4q42534.png)

---

### Real-World Perspective

> Helm becomes especially useful as your cluster begins to host multiple microservices, infrastructure tools (like Prometheus, Grafana, cert-manager), or shared internal apps.
>
> In these setups, Helm helps platform teams ship apps as **versioned artifacts**, and enables developers to install or upgrade those apps confidently and consistently.
>
> You can treat every deployment like a software release — tracked, revertible, and reproducible:
>
> ```bash
> helm install myapp ./my-chart
> helm upgrade myapp ./my-chart --set image.tag=1.2.0
> helm rollback myapp 1
> ```

Helm provides **structure, safety, and simplicity** — turning your raw YAMLs into reusable, portable, and manageable application releases.

---

### How is Helm different?

* **Kustomize** helps with managing multiple environments by allowing you to **patch and overlay YAMLs**. 
* You can **apply** and **delete** resources using `kubectl apply -k` and `kubectl delete -k`. 
* It's helpful when you want to avoid copy-pasting full YAMLs for each environment.
* But **Kustomize is not a full lifecycle management tool**. It handles configuration overlays well, but it doesn't support:
  * Versioning or packaging of applications
  * Rollbacks or release tracking
  * Distribution of your app to other teams or clusters
  * Dynamic templating (e.g., loops, conditionals)
  * Hooks, tests, or lifecycle events
* Helm fills all these gaps and turns your collection of Kubernetes YAMLs into a **single installable unit**.

---

## What is Helm?

**Helm is a package manager for Kubernetes applications.**
Just like:

* `apt` is used to install packages on Debian-based Linux systems
* `Homebrew` is used on macOS
* `Chocolatey` is used on Windows

**Helm** is used to **install, upgrade, rollback, uninstall**, and **distribute** applications on Kubernetes.

You can use Helm to deploy:

* Your own **custom applications**
* **Third-party tools** like Prometheus, Grafana, or Cert-Manager
* Even **Kubernetes Operators** and controllers

But Helm isn’t just a one-time install tool. It supports the full lifecycle of an application on Kubernetes — install, upgrade, rollback, delete — and even allows you to **package your app into a Helm Chart**, which others can easily install with a single command.

> In other words, Helm for Kubernetes is what `apt` is for Debian — you can install, remove, and upgrade software using versioned packages, with built-in support for values and configuration.

---

### Why Helm Needs to Understand Your Application

Kubernetes doesn’t actually understand your application.
To Kubernetes, your app is **just a collection of resources** — Deployments, Services, ConfigMaps, PVCs, Secrets, and so on. These are deployed and managed independently, and Kubernetes doesn't know how they relate to one another.

This is where **Helm adds intelligence**.

> Helm groups all your Kubernetes objects into a single logical unit called a **Helm Chart**.
> When you install that chart, Helm tracks it as one cohesive **Release**, treating your entire app as a unified package.

Because of this grouping:

* Helm understands your application **as a whole**, not just as individual YAMLs.
* It can manage the **entire lifecycle** of the app:
  ✅ **Install** all components together
  🔄 **Upgrade** them with new values or templates
  ⬅️ **Rollback** to a previous state if something breaks
  ❌ **Uninstall** cleanly and remove all related resources

This application-level awareness makes Helm far more powerful than just running `kubectl apply -f`.

> It’s not just about deploying YAMLs — it’s about managing your app’s full lifecycle with safety, repeatability, and control.

---

### Installing Helm

To install Helm, follow the official guide:
🔗 [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)

```bash
helm version
```
```bash
version.BuildInfo{
  Version:"v3.18.3",
  GitCommit:"6838ebcf265a3842d1433956e8a622e3290cf324",
  GitTreeState:"clean",
  GoVersion:"go1.24.4"
}
```
> **Note**: Helm v2 required a component called **Tiller** to be installed inside your Kubernetes cluster. This is **no longer needed in Helm v3**.
> Helm now runs entirely from the client machine and interacts with your Kubernetes cluster just like `kubectl` does using API calls.
> *“How does Helm know which cluster to talk to?”*
Helm uses the **current Kubernetes context**, just like `kubectl`. So the commands you run using Helm apply to the **current context in your kubeconfig**.
If you're unsure about Kubernetes contexts or how they work, I highly recommend revisiting:
📂 **GitHub (Day 32):** [GitHub Notes](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2032)
🎥 **YouTube (Day 32):** [YouTube Video](https://www.youtube.com/watch?v=VBlI0IG4ReI&ab_channel=CloudWithVarJosh)

---

### Helm Core Concepts

![Alt text](/images/43b.png)

Helm revolves around three key concepts:

### 1. Chart

A **Chart** is a Helm package. It contains everything you need to deploy an application, service, or tool on Kubernetes — including:

* Resource templates (Deployments, Services, ConfigMaps, etc.)
* A default configuration file (`values.yaml`)
* Chart metadata (`Chart.yaml`)
* Optional test hooks, helper templates, and dependencies

Think of a chart as a **reusable, versioned blueprint** of your app.

---

### 2. Repository

A **Repository** is a place where charts are stored and shared — similar to how `apt` downloads Debian packages from an APT repository.

* Helm repositories host **Helm Charts** (not packages).
* You can add multiple repos locally, search them, and install charts from them.

> When you create a Helm bundle for your app, it’s called a **Helm Chart**, not a Helm package.

When you want to install applications using Helm, the first thing you need is access to **Helm Charts** — these are versioned, packaged definitions of Kubernetes applications.

These charts are hosted on **Helm Repositories**. Some of the most popular public repositories include:

* **Bitnami**: A trusted source with charts for Prometheus, Grafana, MySQL, NGINX, and many more
* **TrueCharts**: Community-maintained charts, often used with TrueNAS and similar platforms
* **Stakater**, **Grafana**, **Jetstack**, and many others depending on your needs

But here's the good news:

> You don’t need to visit each of these repositories individually to find charts.

---

### Enter Artifact Hub

[Artifact Hub](https://artifacthub.io) is a **centralized search and discovery platform** for Helm Charts.

It aggregates charts from **hundreds of Helm repositories** — both official and community — into one place.

> In summary, Helm Charts are hosted across many repositories, but **Artifact Hub aggregates them into a single interface**, saving you time and ensuring you're using trusted sources.

---

### 3. Release

A **Release** is a running instance of a Helm chart in your Kubernetes cluster. Every time you install a chart, Helm creates a release — and you provide a **unique name** for that release with unique config.


> 🔍 **Note:** The commands shown in this section are included for completeness.
> We will walk through each of these commands and their outputs **in detail during the demo section** of this lecture.

For example:

```bash
helm install app1-prod ./my-app-chart
```

* You're installing the chart `my-app-chart`
* The release name is `app1-prod`

Why does this matter?

* You can **track** the lifecycle of each release (installs, upgrades, rollbacks)
* You can **upgrade** and **rollback** releases independently
* You can **install the same chart multiple times** — each instance tracked as a separate release

**Hierarchy:**
**Repository** → contains → **Charts** → installed as → **Releases**



---

> 📝 **Note: Helm Lets You Install the Same Chart Multiple Times — Each as a Separate Release**

This is especially useful in real-world setups:

* You may already have a production instance running:

  ```bash
  helm install app1-prod ./my-app-chart
  ```

* Now, you want a test copy (same chart, same configs) to debug an issue or test a patch:

  ```bash
  helm install app1-prod-test ./my-app-chart
  ```

Helm treats both as **independent releases**, each with its own:

* Values (`values.yaml`)
* Revision history
* Lifecycle commands (`upgrade`, `rollback`, `uninstall`)

> Helm ensures resources from each release are scoped and labeled to avoid conflicts — so even identical charts can coexist safely.

This kind of **release-level isolation** is powerful when cloning production, testing upgrades, or deploying per-customer environments.

---

### Helm Tracks Release Revisions

Each release maintains a full **revision history** — tracking every `install`, `upgrade`, or `rollback`.

To view a release's revision history:

```bash
helm history app1-prod-test
```

You'll see a table of all revisions, their status, timestamps, and any notes.

To rollback to a specific revision:

```bash
helm rollback app1-prod-test 2
```

> This revision system provides **auditable, versioned, and safe deployments**, especially in fast-changing environments where control matters.

---

### Helm vs Docker Analogy

| Helm Concept         | Docker Concept                       | Description                                                                                                                          |
| -------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Chart**            | **Container Image**                  | A chart is a packaged application definition — just like a Docker image contains a packaged filesystem and metadata for a container. |
| **Chart Repository** | **Image Registry (like Docker Hub)** | A chart repo is a place to **store and share charts**, similar to how Docker images are stored in Docker Hub, ECR, etc.              |
| **Release**          | **Running Container**                | A Helm release is a **live, running instance** of a chart in a cluster — like a container is a live instance of an image.            |


| Tool       | Build                     | Push to Registry                 | Run (Live Object)          |
| ---------- | ------------------------- | -------------------------------- | -------------------------- |
| **Docker** | `docker build`            | `docker push`                    | `docker run` (→ container) |
| **Helm**   | `helm package` (optional) | `helm push` (or shared via repo) | `helm install` (→ release) |


#### Docker Flow:
* You build a `nginx:1.22` image
* Push it to Docker Hub
* Run a container: `docker run nginx:1.22`

#### Helm Flow:
* You create a Helm chart for nginx
* Push it to a chart repo (e.g., Bitnami)
* Install it into your cluster: `helm install my-nginx bitnami/nginx` → this creates a **release**


> “If a **Helm chart** is like a **Docker image** (a packaged, versioned blueprint), then a **Helm release** is like a **running container** — a live, configurable instance of that chart in your cluster. And just like Docker pulls images from an **image registry**, Helm pulls charts from a **chart repository**.”

---

```bash
# -------------------- HELM INSTALLATION --------------------

# Install Helm on macOS using Homebrew
brew install helm

# Install Helm on Ubuntu/Debian using apt
sudo apt update
sudo apt install helm -y

# Install Helm on RHEL/CentOS/Fedora using dnf
sudo dnf install helm -y
```

---

```bash
# -------------------- KUBERNETES CONTEXT (HOW HELM KNOWS WHICH CLUSTER) --------------------

# List all Kubernetes contexts (clusters)
kubectl config get-contexts

# Show current active Kubernetes context
kubectl config current-context

# Helm uses the SAME current context as kubectl to deploy applications
```

---

```bash
helm repo add my-bitnami https://charts.bitnami.com/bitnami #Add a Repository
```
> A Helm repository is a centralized location that stores Helm charts.
> A popular Helm repo is **Bitnami**, which offers production-ready charts for tools like NGINX, Prometheus, Kafka, MySQL, and more.
> ⚠️ We're calling it `my-bitnami` intentionally to show that **this is your alias**, not the official name. You can name it anything.

---

```bash
helm repo list # List all added Helm repositories
```
Output:
```
NAME         	URL
stellarhosted	https://stellarhosted.github.io/helm-charts
my-bitnami   	https://charts.bitnami.com/bitnami
```

---

```bash
helm search repo #List all charts in all repo
helm search repo my-bitnami #List charts in specific repo
helm search repo my-bitnami | grep -i nginx #grep specific charrt
```
> 📝 Note: `helm search repo` only searches **your locally added repositories**. No network call is made — it works offline once you’ve added the repo.

---

```bash
# Update all added repositories (fetch latest chart info)
helm repo update
# Similar to apt update, refreshes available charts and versions
```

---

```bash
helm search hub nginx #Search Artifact Hub for Charts
```
> This command searches **[Artifact Hub](https://artifacthub.io/)** — a centralized index of Helm charts from multiple publishers like Bitnami, TrueCharts, etc.

---

```bash
helm search hub nginx | grep -i bitnami #Filter Artifact Hub Results for Bitnami
```
> 📝 Note: `helm search hub` performs an **online search** across all Artifact Hub publishers. This is different from `helm search repo`, which only works with **local repositories** you’ve added via `helm repo add`.


---

```bash
helm install -h #Help
```

---

```bash
helm install my-nginx my-bitnami/nginx #Install a Chart
```
* `my-nginx` is the release name
* `my-bitnami/nginx` refers to the chart

```bash
# Install NGINX chart with a release name
helm install nginx-v1 bitnami/nginx
# Theory:
# - nginx-v1 → release name (unique deployed instance)
# - bitnami/nginx → chart location (repo/chart)
```
```bash
# Install Prometheus with a release name
helm install prometheus bitnami/prometheus
# Theory: Helm installs all required Kubernetes resources automatically
```

---

```bash
helm uninstall my-nginx #Uninstall a Chart
```
```bash
# Uninstall NGINX using release name
helm uninstall nginx-v1
# Theory: Deletes all Kubernetes resources created by this release

# Uninstall Prometheus
helm uninstall prometheus
# Theory: Release name is mandatory for uninstalling

# Verify pods are removed
kubectl get pods
```

---

```bash
helm upgrade my-nginx my-bitnami/nginx --set image.tag=1.2.3 #Upgrade a Chart
```

---

```bash
# List all installed Helm releases
helm list
# Shows all deployed charts (releases) in the cluster
```

---

```bash
# Get detailed information about a specific release
helm status nginx-v1
# Shows resources, status, and notes for the release
```

---

```bash
# -------------------- INSTALLING FROM NON-BITNAMI REPOSITORIES --------------------

# Add AWS EKS Helm repository (example for AWS Load Balancer Controller)
helm repo add eks https://aws.github.io/eks-charts
# Theory: Some tools maintain their own Helm repositories

# Update repositories after adding a new one
helm repo update

# Search charts in EKS repository
helm search repo eks
# Theory: Lists EKS-related controllers and charts

# Search for AWS Load Balancer Controller
helm search repo eks | grep load
# Theory: Finds the required controller chart

# Install AWS Load Balancer Controller (example)
helm install alb eks/aws-load-balancer-controller
# Theory: Installs Kubernetes controller managed by AWS
```

---

### Creating a Helm Chart

```bash
helm create my-chart #Create a basic boilerplate structure
```
You can visualize the directory using `tree`:
```bash
tree my-chart/
```
Output:
```
my-chart
├── Chart.yaml
├── charts
├── templates
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   └── tests
│       └── test-connection.yaml
└── values.yaml
```

* **`Chart.yaml`** – Metadata about your chart (name, version, description). **Required**
* **`values.yaml`** – Your customization file. Like `kustomization.yaml` in Kustomize, but more powerful. Any input values for templates go here. **Required**
* **`templates/`** – Contains all your manifest templates. These are YAML files with Go templating support (`{{ .Values }}`). **Required**
* **`charts/`** – Holds chart dependencies (if your app depends on other charts). *(Optional, used only when you have dependencies)*
* **`_helpers.tpl`** – Helper templates that can be reused across your YAMLs *(Optional, for DRY templating)*
* **`NOTES.txt`** – Post-install message shown after `helm install` *(Optional, but great for UX — e.g., output app URL, credentials, etc.)*
* **`tests/`** – Contains test hooks that validate your release *(Optional, for writing Helm test jobs)*

> 📦 You can now customize this chart to suit your app, build it, and even publish it to a chart repository for your team or community to consume.

![](/images/image15qw5w5.png)

---

## Conclusion

By the end of Day 43, you’ve learned how Helm transforms raw Kubernetes manifests into structured, versioned, and repeatable application packages. Compared to Kustomize, Helm takes things further with lifecycle operations like **upgrade**, **rollback**, and **distribution** via chart repositories.

You’ve seen Helm in action across three demos:

* **Demo 1**: Build a Helm chart from scratch using templating and values
* **Demo 2**: Simulate Helm’s upgrade and rollback workflows
* **Demo 3**: Reuse a single chart to manage `dev`, `stage`, and `prod` environments with environment-specific values and namespaces

These demos reflect how Helm is used in real production setups — not just as a templating engine, but as a full application lifecycle tool for Kubernetes.

---

## References

* Official Helm Docs: [https://helm.sh/docs/](https://helm.sh/docs/)
* Helm Installation: [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)
* Artifact Hub (Central Chart Index): [https://artifacthub.io/](https://artifacthub.io/)
* Chart Structure: [https://helm.sh/docs/topics/charts/](https://helm.sh/docs/topics/charts/)
* Helm Templating Guide: [https://helm.sh/docs/chart\_template\_guide/](https://helm.sh/docs/chart_template_guide/)

---
