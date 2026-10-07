# Software Supply Chain Security: SBOM and Image Scanning Guide

## Evolution of Infrastructure and Security

We have evolved a lot when we talk about traditional servers or computers that were packed inside a black box inside one room to an API where we can just go and say "I want an EC2 instance from Amazon." The things have evolved a lot, and now with building IDPs, you can just say "I want a Kubernetes cluster" internally within a team, and you will be able to get that.

**Evolution Path:**
- Rooms → Servers → Virtualization → Cloud → Containers

With this evolution, there is one thing that keeps on getting increased: **the attack surface**. Along with this amazing evolution on how we deploy the software, how the software actually goes from a producer to a consumer, the whole attack surface has increased a lot as well.

---

## The Rise of Open Source and Security Implications

With the rise of Open Source, most of the applications (80-90%) are actually written or consuming open-source software. All the applications that you are building or providing to your customers—whether it's Spotify, Zato, or whatever you are using—are built on top of the open-source ecosystem or deployed on infrastructure that uses Kubernetes. So directly or indirectly, you are using open source software for building your applications.

### What This Means for Security:
- There is a piece of software that might be written by a single person or a group of persons, and you are using that—it's actually a piece of your software too.
- Those softwares also use some libraries and dependencies.
- There is a whole layering of the stack.
- Attackers can now actually attack these small open-source softwares that you are using in your big Enterprise application.

**Critical Point:** If the open-source software is detected with a CVE or it's becoming vulnerable, then your main application that is linked deep within the ecosystem also becomes vulnerable and open to attack.

The **whole software supply chain becomes vulnerable.**

---

## What is SBOM?

**SBOM** stands for **Software Bill of Materials**.

From the naming itself, when a producer is producing the code, it is very important (and lawful these days) to create those bills of materials. That means you need to have:
- What all libraries and dependencies are used
- Where they are coming from
- Who has written the code
- All the important metadata about the software

**Key Considerations:**
- **Producer Side:** Critical to release SBOM information while releasing the artifacts
- **Consumer Side:** Critical to read, analyze, and monitor continuously to understand:
  - What are the vulnerabilities
  - If there are any vulnerabilities
  - Licenses that got expired or changed
  - Any impact on the software they are using

---

## The Food Label Analogy

Just like when you see a food item and you turn it back (or sometimes on the front), you'll be able to find the list of ingredients—what this particular packet is made up of. As a consumer, it's your responsibility to read the information written on the back of the packet to understand:
- Whether it contains anything you have an allergy to
- What you should avoid eating

Similarly, **SBOM** related to a software means that it has the information of the ingredients—where it is coming from, what all went inside this particular software (libraries, dependencies, and all that stuff)—so that you get the dependency graph and you are able to understand what you are actually using within your software.

---

## Three Key Things to Understand

1. **Who is building the software** - very critical to understand
2. **What is being built** - very critical to understand
3. **Where this software is being built** - if the build system itself is compromised, the software you will be using is also tampered and compromised

*Note: This relates to SLSA levels and attestations.*

---

## SBOM Formats

There are different formats of SBOMs:
- **Syft** - have their own SBOM format
- **CycloneDX**
- **SPDX**

These are different formats in which people publish their SBOMs. Similar to how you have images in PNG, SVG, etc., but your system can actually read that.

There's a project in open called **Protobom** that says: no matter what SBOM there is, we'll be able to consume that or read that.

---

## Tools for SBOM Generation and Analysis

### 1. Bomb CLI (Kubernetes)

**Bomb Kubernetes** is the utility to generate SPDX compliant Bill of Materials. It has different commands created as part of the project to create SBOM for the Kubernetes project.

**Installation:**
```bash
wget https://github.com/kubernetes-sigs/bom/releases/download/v0.6.0/bom-amd64-linux
chmod +x bom-amd64-linux 
sudo mv bom-amd64-linux /usr/local/bin/bom
```

**Use bom to generate sbom for controller manager image**
```bash
bom generate spdx-json \
    --image registry.k8s.io/kube-controller-manager:v1.32.0 \
    --output ./sbom1.json
```

### 2. Trivy

Trivy can both **generate** and **read** SBOMs.

**Generate SBOM (CycloneDX format):**
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
sudo mv bin/trivy /usr/local/bin

trivy image --format cyclonedx \
    --output ./sbom2.json \
    registry.k8s.io/kube-controller-manager:v1.32.0
```

**Read SBOM:**
```bash
trivy sbom sbom.json --format json

trivy sbom  ./sbom1.json     --format json     --output ./sbom_check_result.json

cat sbom_check_result.json | jq

trivy sbom  ./sbom2.json 
```

**View with JQ (for beautified output):**
```bash
cat sbom.json | jq
```

---

## Image Scanning with Trivy

Trivy is also used to scan container images and give out vulnerability information after checking its vulnerability database.

### Example Scenario:

**Create deployments:**
```bash
kubectl run p1 --image=nginx
kubectl run p2 --image=httpd
kubectl run p3 --image=alpine -- sleep 1000
```

**Get pod names:**
```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

**Scan images for vulnerabilities (High and Critical):**
```bash
trivy image --severity HIGH,CRITICAL nginx
trivy image --severity HIGH,CRITICAL httpd
trivy image --severity HIGH,CRITICAL alpine
```
```bash
echo p1 $'\n'p2 > /tmp/badimages.txt
```

**Results:**
- nginx: 2 critical vulnerabilities found
- httpd: 1 critical vulnerability found
- alpine: No vulnerabilities found

---

## SBOM in CI/CD Pipelines

### GitHub Actions Workflow Example

Create a workflow that:
1. Runs on push to main branch
2. Checks out the code
3. Installs Trivy
4. Generates SBOM using Trivy (CycloneDX format)
5. Outputs as SBOM with GitHub SHA
6. Uploads as artifact

```yaml
name: Generate SBOM

on:
  push:
    branches:
      - main

jobs:
  generate-sbom:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Install Trivy
        run: |
          curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
          sudo mv bin/trivy /usr/local/bin

      - name: Generate SBOM
        run: |
          IMAGE="registry.k8s.io/kube-apiserver:v1.32.0"
          trivy image --format cyclonedx --output sbom-${{ github.sha }}.json $IMAGE

      - name: Upload SBOM Artifact
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom-${{ github.sha }}.json

```

---

## Key Takeaways for CK (Certified Kubernetes Security) Certification

### Topics Covered:
1. **SBOM Generation** using:
   - Bomb CLI (SPDX format)
   - Trivy (CycloneDX format)

2. **SBOM Analysis** using:
   - Trivy sbom command
   - JQ for JSON visualization

3. **Image Scanning** using Trivy to:
   - Find vulnerabilities
   - Identify critical and high severity issues
   - Make decisions about updating deployments

4. **CI/CD Integration**:
   - Generate SBOMs as part of GitHub Actions
   - Upload artifacts
   - Monitor for vulnerabilities

---

## Summary

In this guide, we've covered:
- **Why SBOM is important** - software supply chain security
- **What SBOM contains** - libraries, dependencies, metadata
- **Two main tools** - Bomb CLI and Trivy
- **How to generate SBOMs** - using both tools
- **How to read SBOMs** - using Trivy
- **Image scanning** - using Trivy for vulnerability detection
- **CI/CD integration** - using GitHub Actions

Remember: SBOM and image scanning are critical components of Kubernetes security and are now part of the CKS certification exam.