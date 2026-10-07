```bash
# =========================
# HELM CHART CREATION – PRACTICAL COMMANDS WITH THEORY
# =========================

# -------------------------
# SCENARIO (THEORY)
# -------------------------
# We are a DevOps engineer in an e-commerce company.
# We have two microservices:
# 1) payments
# 2) shipping
# We want to package both services as Helm charts
# and publish them in a single Helm repository so others
# can install them easily.


# -------------------------
# CREATE BASE DIRECTORY (REPO)
# -------------------------

mkdir -p best-commerce
# Theory: This folder represents the Helm repository for the organization

cd best-commerce


# -------------------------
# CREATE HELM CHART SCAFFOLDING
# -------------------------

helm create payments
# Theory:
# - Creates a complete Helm chart structure for the payments service
# - Includes Chart.yaml, values.yaml, templates/, charts/

helm create shipping
# Theory:
# - Creates another Helm chart for the shipping service


# -------------------------
# HELM CHART STRUCTURE (THEORY)
# -------------------------
# payments/
# ├── Chart.yaml     -> Metadata (name, version, appVersion)
# ├── values.yaml    -> Customizable values
# ├── templates/     -> Kubernetes YAML templates
# └── charts/        -> Dependency charts (optional)


# -------------------------
# EDIT DEPLOYMENT TEMPLATE
# -------------------------

cd payments/templates
rm -f deployment.yaml
# Theory:
# - Remove default example deployment
# - We will use our own clean deployment YAML

# (Add your custom deployment.yaml here using variables like {{ .Values.image.repository }})

cd ../../


# -------------------------
# EDIT VALUES FILE
# -------------------------

cd payments
rm -f values.yaml
# Theory:
# - Remove default values.yaml
# - We define only what we want to customize

# Example values.yaml content (conceptual):
# image:
#   repository: busybox
#   tag: latest
#   pullPolicy: IfNotPresent
# appMessage: "I am a payment service"

cd ../


# -------------------------
# UPDATE CHART METADATA
# -------------------------

# Open payments/Chart.yaml and update:
# appVersion: "1.0.0"
# Theory:
# - appVersion represents the application version
# - version represents the Helm chart version


# -------------------------
# REPEAT SAME STEPS FOR SHIPPING
# -------------------------

cd shipping/templates
rm -f deployment.yaml
# Theory:
# - Deployment template is same as payments
# - Only values.yaml will change

cd ../
rm -f values.yaml
# Example values.yaml difference:
# appMessage: "I am a shipping service"

cd ../


# -------------------------
# PACKAGE HELM CHARTS
# -------------------------

helm package payments
# Theory:
# - Bundles the payments chart into a .tgz file
# - This is the actual Helm chart artifact

helm package shipping
# Theory:
# - Bundles the shipping chart into a .tgz file


# -------------------------
# CREATE HELM REPOSITORY INDEX
# -------------------------

helm repo index .
# Theory:
# - Generates index.yaml
# - This file tells Helm which charts exist in this repository
# - Mandatory for a Helm repository


# -------------------------
# VERIFY REPOSITORY CONTENT
# -------------------------

ls -l
# Theory:
# - You should see:
#   payments-<version>.tgz
#   shipping-<version>.tgz
#   index.yaml

cat index.yaml
# Theory:
# - Shows list of available charts in the repository


# -------------------------
# PUBLISH REPOSITORY (THEORY)
# -------------------------
# Upload the folder contents to:
# - Nexus
# - Artifactory
# - GitHub Pages
# - Any HTTP-accessible location


# -------------------------
# CONSUME CUSTOM HELM REPOSITORY
# -------------------------

helm repo add best-commerce <repository-url>
# Theory:
# - Adds your organization’s Helm repository

helm repo update
# Theory:
# - Fetches index.yaml and chart metadata


# -------------------------
# INSTALL CUSTOM APPLICATIONS
# -------------------------

helm install payments best-commerce/payments
# Theory:
# - Deploys payments microservice using Helm chart

helm install shipping best-commerce/shipping
# Theory:
# - Deploys shipping microservice


# -------------------------
# PASS CUSTOM VALUES DURING INSTALL
# -------------------------

helm install payments best-commerce/payments \
  --set replicaCount=3 \
  --set image.tag=1.0.1
# Theory:
# - --set overrides values.yaml at install time
# - Useful for different environments (UAT, PROD)


# -------------------------
# VIEW AVAILABLE VALUES
# -------------------------

helm show values best-commerce/payments
# Theory:
# - Displays all configurable values for the chart
# - Helps understand what can be customized


# -------------------------
# UNINSTALL APPLICATION
# -------------------------

helm uninstall payments
# Theory:
# - Removes all Kubernetes resources created by the release

helm uninstall shipping
# Theory:
# - Uses release name, not chart name


# =========================
# CORE CONCEPT SUMMARY
# =========================
# Chart      -> Packaged application (YAML + templates)
# Repository -> Collection of charts
# Release    -> Installed instance of a chart
# templates  -> Kubernetes YAML with variables
# values.yaml-> Environment-specific customization
```