## **Name-Based Routing Using ALB Ingress on EKS**

In this demo, we will extend our TLS-secured Ingress setup from Demo 2 and implement **host-based (name-based) routing**. This allows requests to different subdomains (e.g., `iphone.cwvj.click`, `android.cwvj.click`, `cwvj.click`) to be routed to separate services inside the Kubernetes cluster. This is a common pattern in production-grade ingress configurations where applications are hosted under different subdomains.

![Alt text](/images/51b.png)

---

## **Step 1: Request Certificates in ACM**

To enable HTTPS for multiple subdomains, we need valid TLS certificates:

1. Go to **AWS Certificate Manager (ACM)** → Request 2 public certificates:

   * One for the **apex domain**: `cwvj.click`
   * One for **wildcard subdomains**: `*.cwvj.click`

2. Choose **DNS validation** and let ACM **automatically create validation records** in Route 53.

3. Wait for ACM to validate ownership and issue the certificates. These will be used by the ALB to serve HTTPS traffic for all routes.

Note: We can also create the single certificate for `apex domain` and `subdomaines`
---

## **Step 2: Update Deployments and Services**

We modify the application deployment so that requests sent to the root (`/`) path return the desired page content directly, rather than nested under `/iphone` or `/android`.

### **Key Changes**

* The `echo` command now creates `index.html` at the root instead of under `/iphone` or `/android`.
* We update the ALB health check path to `/index.html` instead of `/android/index.html` or similar.

### **Sample Manifest for iPhone Service**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iphone-deploy
  namespace: app1-ns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: iphone-page
  template:
    metadata:
      labels:
        app: iphone-page
    spec:
      containers:
      - name: python-http
        image: python:alpine
        command: ["/bin/sh", "-c"]
        args:
          - |
            echo '<html>
              <head><title>iPhone Users</title></head>
              <body>
                <h1>iPhone Users</h1>
                <p>Welcome to Cloud With VarJosh</p>
              </body>
            </html>' > /index.html && python3 -m http.server 5678
        ports:
        - containerPort: 5678
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: iphone-svc
  namespace: app1-ns
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: /index.html
spec:
  selector:
    app: iphone-page
  ports:
  - protocol: TCP
    port: 80
    targetPort: 5678
```

Repeat similar changes for Android and Desktop services.

---

## **Step 3: Create Ingress for Name-Based Routing**

This ingress defines host-based routing and attaches both ACM certificates to the ALB.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-demo3
  namespace: app1-ns
  annotations:
    # ALB Scheme
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/load-balancer-name: cwvj-ingress-demo3

    # Target Mode
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'

    # Health Checks
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/success-codes: '200'

    # SSL
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-2:261358761470:certificate/6ab64476-8f23-4030-a291-4e8d6a3dcb35,arn:aws:acm:us-east-2:261358761470:certificate/c54d724c-0971-48f8-a901-ebc0e4e408af
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: iphone.cwvj.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: iphone-svc
                port:
                  number: 80
    - host: android.cwvj.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: android-svc
                port:
                  number: 80
    - host: cwvj.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: desktop-svc
                port:
                  number: 80
```

### **Explanation**

* We add both ACM certificates: one for apex (`cwvj.click`) and one for wildcard (`*.cwvj.click`) domains.
* Each rule uses the `host` field to match subdomain requests.
* The path `/` under each host now maps to the corresponding service, thanks to our updated `index.html`.

Apply all manifests from the `demo3` directory:

```bash
kubectl apply -f .
```

---

## **Step 4: Route 53 Alias Records**

To resolve DNS:

* Create alias record: `iphone.cwvj.click` → points to ALB
* Create alias record: `android.cwvj.click` → points to ALB
* Create alias record: `cwvj.click` → points to ALB

All three subdomains should now be resolved via Route 53 and routed correctly through ALB.

> **Note:** You can **automate this entire DNS record creation** process using **[ExternalDNS](https://github.com/kubernetes-sigs/external-dns)** — a Kubernetes-native controller that dynamically manages DNS records based on your Ingress and Service resources. This demo focuses on manual setup to better understand the underlying pieces, but ExternalDNS is worth exploring for production-grade workflows.

---

## **Step 5: Verification**

Verify each of the below:

* `https://iphone.cwvj.click` → should return iPhone page
* `https://android.cwvj.click` → should return Android page
* `https://cwvj.click` → should return Desktop (catch-all) page

You can inspect listener rules in ALB to confirm host and path conditions are matching correctly.

---

## **Step 6: Cleanup**

To clean up:

1. From the `demo3` directory:

   ```bash
   kubectl delete -f .
   ```

2. In **ACM**, delete both certificates.

3. In **Route 53**, remove alias records for:

   * `iphone.cwvj.click`
   * `android.cwvj.click`
   * `cwvj.click`

4. If you’re done with the cluster:

   ```bash
   eksctl delete cluster --name cwvj-ingress-demo --region us-east-2
   ```
