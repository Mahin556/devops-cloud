## **Ingress with TLS and Custom Domain Integration on Amazon EKS**

In this demo, we will elevate our basic ingress setup into a more **production-ready configuration** by integrating:

* A custom domain purchased via **Route 53**
* A **TLS certificate** issued using **AWS Certificate Manager (ACM)**
* ALB configuration to accept **only HTTPS (port 443)** traffic
* **Host-based routing** support (in follow-up steps)

![Alt text](/images/51a.png)

> Note: If you're using AWS Free Tier or credits, be aware that Route 53 domain registration is a **paid** service. As an example, `.click` TLD domains typically cost around **\$3/year**, which is reasonable for your personal learning lab.

---

```bash
┌──────────────────────────────────────────────────────────────────────────┐
│ DEMO 2 — INGRESS WITH TLS & CUSTOM DOMAIN (MAIN IDEAS)                  │
│                                                                          │
│ 1) GOAL OF DEMO 2                                                        │
│ • Improve previous Ingress setup                                        │
│ • Use a CUSTOM DOMAIN instead of ALB DNS name                           │
│ • Enable HTTPS (TLS on port 443)                                        │
│                                                                          │
│ 2) WHY IMPROVEMENTS ARE NEEDED                                           │
│ • ALB DNS name is NOT user-friendly                                     │
│ • Production websites must use HTTPS                                    │
│ • HTTP (port 80) is not trusted on the internet                          │
│                                                                          │
│ 3) DOMAIN REGISTRATION WITH ROUTE 53                                     │
│ • Route 53 is used as:                                                   │
│   • Domain Registrar                                                    │
│   • DNS Hosting Provider                                                 │
│ • Domain example: cloudwithvarosh.click                                 │
│                                                                          │
│ 4) ROUTE 53 ROLE                                                         │
│ • Hosts the DNS zone (zone file)                                         │
│ • Route 53 name servers become authoritative                             │
│ • DNS resolves domain → ALB IP/DNS                                      │
│                                                                          │
│ 5) TLS CERTIFICATE USING ACM                                             │
│ • TLS enables HTTPS                                                     │
│ • Certificate is issued using AWS Certificate Manager (ACM)             │
│ • TLS is a Layer 7 (HTTP) feature                                        │
│                                                                          │
│ 6) TLS TERMINATION AT ALB                                                │
│ • ALB is a Layer 7 load balancer                                         │
│ • ALB understands HTTPS/TLS                                             │
│ • ALB terminates TLS using ACM certificate                               │
│                                                                          │
│ 7) INGRESS CONTROLS TLS CONFIG                                           │
│ • TLS settings are defined in Ingress YAML                              │
│ • Annotations tell controller to attach certificate                      │
│ • No manual ALB configuration                                           │
│                                                                          │
│ 8) WHAT DOES NOT CHANGE                                                  │
│ • Same Ingress rules                                                     │
│ • Same services (iPhone, Android, Desktop)                              │
│ • Same target groups                                                     │
│ • Same pod routing                                                      │
│                                                                          │
│ 9) REQUEST FLOW (END TO END)                                             │
│ • User accesses:                                                        │
│   https://cloudwithvarosh.click/iphone                                   │
│                                                                          │
│ • DNS resolution:                                                       │
│   Browser/ISP → Route 53 (if not cached)                                │
│                                                                          │
│ • DNS returns ALB address                                                │
│                                                                          │
│ • Request reaches ALB                                                    │
│ • ALB terminates TLS (HTTPS → HTTP internally)                           │
│                                                                          │
│ • ALB applies path-based routing                                         │
│ • Request forwarded to iPhone target group                               │
│                                                                          │
│ • Target group forwards directly to iPhone Pod IPs                      │
│                                                                          │
│ • Container responds on port 5678                                       │
│                                                                          │
│ 10) KEY TAKEAWAYS                                                        │
│ • Domain + HTTPS is production standard                                  │
│ • Route 53 handles DNS & domain                                          │
│ • ACM provides TLS certificates                                         │
│ • Ingress YAML defines LB + TLS config                                   │
│ • ALB handles TLS termination                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---


## **Step 1: Register Domain and Request TLS Certificate**

1. Go to the **Route 53 Console** → **Domains** → Register your domain (e.g., `cwvj.click`).
2. Once registered, Route 53 will automatically create a hosted zone with **4 name servers**.
3. Now navigate to **AWS Certificate Manager (ACM)** → **Request a certificate**.
4. Choose **"Request a public certificate"**, and enter your domain name (`cwvj.click`).
5. Choose **DNS validation**, and when prompted, allow ACM to **create the validation records** in Route 53.
6. ACM will verify the DNS ownership via CNAME records, and issue the certificate once the validation succeeds.

* If you are using other certificatye manager you nned to manually create a CNAME record.
---

## **Step 2: Update Ingress Resource to Enable HTTPS(configure a ALB)**

Update your Ingress manifest to:

* Attach the **issued ACM certificate**
* Enable **port 443**
* Add **SSL redirection**

```yaml
# 05-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-demo2
  namespace: app1-ns
  annotations:
    # Basic ALB configuration
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/load-balancer-name: cwvj-ingress-demo2
    alb.ingress.kubernetes.io/target-type: ip

    # ALB Listener configuration (enable both HTTP and HTTPS)
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'

    # SSL settings
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-2:261358761470:certificate/6ab64476-8f23-4030-a291-4e8d6a3dcb35
    alb.ingress.kubernetes.io/ssl-redirect: '443'

    # Health check parameters (inherited by each target group from service annotations)
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/success-codes: '200'

spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /iphone
            pathType: Prefix
            backend:
              service:
                name: iphone-svc
                port:
                  number: 80
          - path: /android
            pathType: Prefix
            backend:
              service:
                name: android-svc
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: desktop-svc
                port:
                  number: 80
```

> You can now apply the manifests (assuming you’re in the `demo2/` directory):

```bash
kubectl apply -f .
```

---

### **Step 3: Create a Route 53 Record**

Once the ALB is provisioned and you have the **DNS name** from `kubectl get ingress ingress-demo2` or the **AWS Console**, you’ll need to associate your domain with this ALB.

**Instructions:**

1. Navigate to **Route 53 → Hosted Zones → cwvj.click**.
2. Click **Create Record**.
3. Since we are setting this up for the **apex domain/root domain** (`cwvj.click`), leave the **Record name** blank.
4. Select **Alias**.
5. Under “Route traffic to”, choose:

   * **Alias to: Application and Classic Load Balancer**
   * **Region: us-east-2** (or your cluster’s region)
   * **Choose Load Balancer:** Select the ALB provisioned by your Ingress (it should contain `cwvj-ingress-demo2` in the name).
6. Click **Create records**.

This will ensure that `https://cwvj.click` (and its subpaths) resolve to your newly provisioned AWS ALB.

```bash
┌──────────────────────────────────────────────────────────────────────────┐
│ ROUTE 53 ALIAS RECORD — MAIN IDEAS                                      │
│                                                                          │
│ 1) WHAT IS AN ALIAS RECORD                                               │
│ • Route 53 Alias maps a DOMAIN NAME directly to an AWS resource          │
│ • Examples of targets:                                                   │
│   • Application Load Balancer (ALB)                                      │
│   • CloudFront distribution                                              │
│   • S3 static website                                                    │
│                                                                          │
│ • Alias record does NOT store an IP address                              │
│                                                                          │
│ 2) WHY ALIAS RECORD IS SPECIAL                                           │
│ • Supports APEX (root) domains                                           │
│   Example:                                                               │
│   cloudwithvjos.click  → ALB                                             │
│                                                                          │
│ • No extra DNS query charges                                             │
│ • Resolved internally by Route 53                                        │
│                                                                          │
│ 3) ALIAS vs CNAME                                                        │
│ • CNAME:                                                                │
│   • Cannot be used at apex domain                                        │
│   • Always points to another DNS name                                    │
│                                                                          │
│ • ALIAS:                                                                │
│   • Works at apex domain                                                  │
│   • Points to AWS resources directly                                     │
│   • Resolved internally by Route 53                                      │
│                                                                          │
│ 4) IMPORTANT CLARIFICATION — NOT HTTP REDIRECT                           │
│ • Alias is NOT an HTTP redirect (301/302)                                │
│ • It is purely DNS-level resolution                                     │
│                                                                          │
│ 5) DNS RESOLUTION FLOW                                                   │
│ • User queries: cloudwithvjos.click                                      │
│                                                                          │
│ • Route 53 authoritative name servers:                                   │
│   • See alias record                                                     │
│   • Return the ALB DNS name                                               │
│                                                                          │
│ • User’s ISP / public resolver (Google DNS, Cloudflare):                 │
│   • Performs DNS lookup for the ALB DNS name                              │
│   • AWS authoritative servers respond with IP addresses                  │
│                                                                          │
│ • Browser connects to ALB IP                                             │
│                                                                          │
│ 6) WHY THIS DESIGN IS USED                                                │
│ • ALB IPs change dynamically                                             │
│ • DNS always resolves correctly without manual updates                   │
│                                                                          │
│ 7) KEY TAKEAWAY                                                          │
│ • Alias = AWS-native DNS mapping                                         │
│ • Works for root domains                                                 │
│ • No HTTP redirect involved                                              │
│ • Best practice for ALB + Route 53 integration                           │
└──────────────────────────────────────────────────────────────────────────┘
```
---


## **Step 4: Verification**

Try accessing the following URLs:

```bash
https://cwvj.click/
→ Desktop Users
→ Welcome to Cloud With VarJosh

https://cwvj.click/iphone/
→ iPhone Users
→ Welcome to Cloud With VarJosh

https://cwvj.click/android/
→ Android Users
→ Welcome to Cloud With VarJosh
```

The following behaviors should be observed:

* All HTTP requests should **automatically redirect** to HTTPS (`port 443`) as per the `ssl-redirect` annotation.
* The correct TLS certificate is served (verify in browser’s padlock → certificate → subject).
* The ALB Listener for **HTTPS (443)** should have your ACM cert attached and have routing rules derived from your Ingress paths.

You can inspect rules under:
**AWS Console → EC2 → Load Balancers → Listeners → HTTPS:443 → View/edit rules**

---

**Note on Wildcard Certificates**

If your certificate only covers `*.cwvj.click`, then the apex domain `cwvj.click` **will not be trusted** by browsers. To avoid browser warnings:

* **Reissue the cert** with both:

  * `*.cwvj.click`
  * `cwvj.click`

This ensures full coverage.

---

### **Step 5: Cleanup**

Demo 2 introduced secure access to your application using a custom domain and TLS. If you're not continuing immediately to Demo 3, here’s how to clean up what was created during this step:

#### **1. Delete Kubernetes Resources**

Run the following from the `demo2` directory:

```bash
kubectl delete -f .
```

This will delete the Ingress resource with TLS and any deployments or services defined within the same directory.

#### **2. Delete the ACM Certificate**

Navigate to **AWS Certificate Manager (ACM)** in the AWS Console and delete the **public certificate** you requested for your domain (`cwvj.click` or similar). This prevents unused certificates from lingering in your account.

#### **3. Delete the Route 53 Alias Record**

Go to **Route 53 → Hosted Zones → cwvj.click** and delete the **alias A record** that was created to point your apex domain (`cwvj.click`) to the ALB.

> ⚠️ Do **not** delete the hosted zone or domain registration if you plan to use them in **Demo 3** for host-based routing.

#### **4. Wait for ALB Auto-Cleanup (Optional)**

Once the Ingress is deleted, the **AWS Load Balancer Controller** will automatically remove the ALB provisioned for this configuration. You can monitor progress from **EC2 → Load Balancers**.

#### **5. Retain the Cluster**

The same EKS cluster (`cwvj-ingress-demo`) will be reused in **Demo 3**, where we’ll configure **name-based routing** with subdomains like `iphone.cwvj.click` and `android.cwvj.click`.

If you do not plan to proceed right away and wish to reclaim all resources, you can delete the cluster later using:

```bash
eksctl delete cluster --name cwvj-ingress-demo
```
