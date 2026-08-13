# 🔐 Trivy Tutorial – Complete DevSecOps Security Scanning Guide

![Trivy](https://img.shields.io/badge/Scanner-Trivy-blue?logo=aqua)
![Docker](https://img.shields.io/badge/Docker-Enabled-blue?logo=docker)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Shift--Left-success)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

This repository contains **end-to-end hands-on demos and automation scripts for Trivy**, aligned **chapter-by-chapter with the Trivy One‑Shot YouTube Masterclass**.

<p align="center">
<img width="1280" height="720" alt="Blue Black and White Bold Social Media Growth YouTube Thumbnail" src="https://github.com/user-attachments/assets/032d0269-3abb-485f-a508-8462cf0649ca" />
</p>

It covers **Docker image scanning, filesystem scans, secret detection, SBOM, automation, and enterprise concepts**, following real-world **DevSecOps best practices**.

---

## 🎯 Who Is This For?

- DevOps Engineers  
- DevSecOps Engineers  
- Cloud & Platform Engineers  
- Security Engineers  
- Students preparing for interviews  
- Anyone learning container security  

---

## 🎥 YouTube One‑Shot – Chapter Alignment

| Timestamp | Topic |
|--------|------|
| 00:00 | Why security issues start before production |
| 01:10 | What is Trivy & why DevSecOps needs it |
| 03:00 | Trivy architecture & scan types |
| 06:30 | Installing Trivy (Linux / macOS / Windows) |
| 10:20 | Docker image vulnerability scanning |
| 16:45 | Understanding CVEs & severities |
| 22:30 | Fixing vulnerabilities in images |
| 29:10 | Filesystem scanning – `trivy fs` |
| 36:40 | Secret scanning explained |
| 44:50 | Handling false positives |
| 52:20 | Git repository scanning |
| 59:30 | SBOM explained (CycloneDX & SPDX) |
| 01:09:10 | Trivy automation with shell scripts |
| 01:18:40 | Trivy Server Mode (enterprise) |
| 01:30:20 | Real DevSecOps workflows |
| 01:38:00 | Key takeaways |

---

## 📂 Repository Structure

```
trivy-tutorial/
├── 1-trivy-installation/
├── 2-trivy-main-flags/
├── 3-trivy-security-fix-local/
├── 4-trivy-security-fix-dockerhub/
├── 5-trivy-alternative/
├── 6-trivy-report-generation/
├── 7-trivy-fs-demo/
├── scripts/
├── README.md
```

---

## 🛠️ Prerequisites

- Docker
- Basic Linux commands
- Trivy installed

```bash
trivy --version
```

---

## 🔍 Common Trivy Commands

### Scan Docker Image
```bash
trivy image nginx:latest
```

### Scan Local Filesystem
```bash
trivy fs .
```

### Secret Scanning Only
```bash
trivy fs --scanners secret .
```

### Scan Git Repository
```bash
trivy repo https://github.com/your-org/your-repo
```

### Generate SBOM
```bash
trivy image --format cyclonedx nginx:latest
```

---

## 🤖 Automation (Real DevSecOps Use Case)

This repo includes **shell scripts** to automate daily security scans, commonly used with:
- Cron jobs
- CI/CD pipelines
- Pre-commit hooks

Automation ensures security is **continuous, not manual**.

---

## 🏢 Enterprise / Production Concepts

- Trivy Server Mode (centralized scanning)
- Reduced DB downloads
- Faster CI/CD pipelines
- Ideal for large-scale DevSecOps teams

---

## 📄 Resources

- 📦 GitHub Repo: https://github.com/theshubhamgour/trivy-tutorial  
- 📊 PPT Slides: https://drive.google.com/file/d/1PN_IXnveUYOs_6Au4Wd_V1sfXdn90zWX/view?usp=sharing  

---

## ⭐ Support & Community

If this repo helped you:

- ⭐ Star the repository  
- 🍴 Fork it  
- 🔁 Share it with your DevOps network  

Happy Secure Coding 🔐  
