# Trivy Docker Image Scanning Scripts

This repository contains **simple and practical shell scripts** to scan Docker images using **Trivy** and generate vulnerability reports in different formats.

It is designed for **DevOps / DevSecOps engineers**, beginners as well as professionals, who want quick security scans without complex setup.

---

## 📌 What is Trivy?

**Trivy** is an open‑source vulnerability scanner developed by Aqua Security.  
It scans:
- Docker images
- Filesystems
- Git repositories
- Kubernetes clusters

and detects:
- OS package vulnerabilities
- Application dependency vulnerabilities
- Secrets
- Misconfigurations

---

## 📂 Files in This Repository

### 1️⃣ `trivy-scan.sh`
Generates a **text-based (table) vulnerability report**.

### 2️⃣ `trivy-scan-html.sh`
Generates a **HTML vulnerability report** (browser-friendly).

---

## 📁 Output Structure

All scan reports are automatically stored inside:

```
trivy-reports/
```

Each report is timestamped to avoid overwriting old scans.

Example:
```
trivy-reports/
├── trivy-scan-2026-01-08_10-30.txt
├── trivy-scan-2026-01-08_10-32.html
```

---

## 🛠️ Prerequisites

Before running the scripts, ensure:

- Linux / macOS
- Docker installed and running
- Trivy installed

### Install Trivy
```bash
sudo apt install trivy
# OR
brew install trivy
```

Verify:
```bash
trivy --version
```

---

## 🚀 How to Use

### Step 1: Give execute permission
```bash
chmod +x trivy-scan.sh
chmod +x trivy-scan-html.sh
```

---

### Step 2: Run Text Report Scan

```bash
./trivy-scan.sh
```

You will be asked:
```
Enter image name :
```

Example:
```bash
nginx:latest
```

📄 Output:
- `trivy-reports/trivy-scan-<date>.txt`

---

### Step 3: Run HTML Report Scan

```bash
./trivy-scan-html.sh
```

Enter image name:
```bash
nginx:latest
```

🌐 Output:
- `trivy-reports/trivy-scan-<date>.html`
- Open in browser:
```bash
xdg-open trivy-reports/trivy-scan-*.html
```

---

## 🔍 What Exactly Is Being Scanned?

Both scripts scan:

- **Docker image layers**
- **OS packages**
- **Only HIGH and CRITICAL vulnerabilities**

### Severity Filter Used
```bash
--severity HIGH,CRITICAL
```

---

## 🧠 Script Explanation (Important)

### Common Logic (Both Scripts)

- Prompts user for Docker image name
- Creates report directory if not present
- Adds timestamp to each report
- Runs Trivy image scan

---

### HTML Script Uses:
```bash
--format template
--template "@html.tpl"
```

This creates a **clean vulnerability dashboard** useful for:
- Audits
- Management reports
- Security reviews

---

### TXT Script Uses:
```bash
--format table
```

This creates a **CLI-friendly report** useful for:
- Logs
- CI/CD pipelines
- Quick checks

---

## 📈 Use Cases

✔️ Daily Docker image scanning  
✔️ Pre‑production security checks  
✔️ CI/CD pipeline integration  
✔️ DevSecOps learning projects  
✔️ Audit & compliance evidence  

---

## 🔐 Best Practices

- Always scan images before deployment
- Focus on HIGH & CRITICAL vulnerabilities
- Fix base image issues first
- Re-scan after upgrades

---

## ⚠️ Disclaimer

This script **does not fix vulnerabilities** — it only reports them.  
Use patching, base image updates, or dependency upgrades to remediate.

---

## ⭐ Recommendation

For advanced usage:
- SBOM generation (CycloneDX, SPDX)
- Git repo scanning
- Kubernetes scanning
- Automation with Jenkins / GitHub Actions

---

## 🙌 Author

Created for learning, automation, and DevSecOps awareness.

If you are using this for tutorials or YouTube demos — it’s perfect 🚀

