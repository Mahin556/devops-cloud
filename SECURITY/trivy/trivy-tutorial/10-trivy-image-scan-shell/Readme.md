# 🛡️ Trivy Docker Image Security Scan Automation

This repository contains a **production-ready Bash script** to scan multiple Docker images for **HIGH** and **CRITICAL** vulnerabilities using **Trivy**, and generate **HTML vulnerability reports** automatically.

---

## 📌 Features

- ✅ Scans **multiple Docker images** from a single input file
- ✅ Uses **Trivy** industry-standard vulnerability scanner
- ✅ Generates **beautiful HTML reports**
- ✅ Filters only **HIGH & CRITICAL** vulnerabilities
- ✅ Fail-fast and safe Bash execution (`set -euo pipefail`)
- ✅ Ideal for **CI/CD, DevSecOps & Release Engineering**

---

## 📂 Project Structure

```
.
├── trivy-image-scan.sh          # Main scanning script
├── scan-image.txt          # List of Docker images to scan
├── html.tpl                # Trivy HTML template (auto-downloaded)
├── reports/                # Generated HTML reports
│   ├── nginx_latest.html
│   ├── python_3.11.html
└── README.md
```

---

## 🧾 Prerequisites

Make sure the following tools are installed:

- **Docker**
- **Trivy**
- **wget**
- **Linux / macOS (Bash shell)**

### Install Trivy (Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy
```

---

## 📄 Input File (`scan-image.txt`)

Add Docker images **one per line**:

```
nginx:latest
python:3.11-slim
redis:7
amazonlinux:2
```

---

## ▶️ Script Usage

### Make script executable

```bash
chmod +x scan-images.sh
```

### Run the scan

```bash
./scan-images.sh
```

---

## 🧪 What the Script Does

1. Validates required tools (`trivy`, `wget`)
2. Validates `scan-image.txt`
3. Downloads Trivy HTML template (only once)
4. Scans each Docker image
5. Generates HTML reports per image
6. Saves reports inside `/reports` folder

---

## 📊 Sample Output

```
🔍 Scanning: nginx:latest
✅ Report generated: reports/nginx_latest.html
--------------------------------------
🔍 Scanning: python:3.11
✅ Report generated: reports/python_3.11.html
--------------------------------------
All scans completed successfully
```

---

## 📁 Report Naming Logic

| Docker Image | HTML Report |
|-------------|------------|
| nginx:latest | nginx_latest.html |
| python:3.11 | python_3.11.html |
| amazonlinux:2 | amazonlinux_2.html |

---

## 🔐 Security Scope

- **Severity Filtered:** `HIGH`, `CRITICAL`
- **Scan Type:** Image vulnerability scan
- **Output Format:** HTML (shareable & audit-friendly)

---

## 🚀 CI/CD & Jenkins Ready

This script can be directly integrated into:

- Jenkins pipelines
- GitHub Actions
- GitLab CI
- Cron jobs
- Release governance checks

---

## 🧠 Best Practices

- Run with **cached Trivy DB** for faster scans
- Schedule scans daily using **cron**
- Archive HTML reports in CI artifacts
- Enforce blocking on CRITICAL findings in pipelines

---

## 👨‍💻 Author

**Shubham Gour**  
Release Engineer | DevSecOps | Cloud & Automation  

---

## ⭐ If this helped you

Give the repo a ⭐ and share it with your DevSecOps team 😊
