### Types of TLS Certificate Authorities (CA): Public, Private, and Self-Signed

CAs are part of **Public Key Infrastructure (PKI)**, which includes:
* Digital Certificates
* Public/Private Key Pairs
* Certificate Signing Requests (CSRs)
* Certificate Authorities (CA)

When enabling HTTPS or TLS for applications, certificates must be signed to be trusted by clients. There are three common ways to achieve this:
1. **Public CA** – Used for production websites accessible over the internet (e.g., Let's Encrypt, DigiCert).
2. **Private CA** – Used within organizations for internal services (e.g., `*.internal` domains).
3. **Self-Signed Certificates** – Quick to create, mainly used for testing, but not trusted by browsers.

**Public CA vs Private CA vs Self-Signed Certificates**

| **Certificate Type**         | **Use Case**                                      | **Trust Level**                 | **Common Examples**                       | **Typical Use**                                                                        |
| ---------------------------- | ------------------------------------------------- | ------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------- |
| **Public CA**                | Production websites, accessible over the internet | Trusted by all major browsers   | Let's Encrypt, DigiCert, GlobalSign       | Used for production environments and public-facing sites                               |
| **Private CA**               | Internal services within an organization          | Trusted within the organization | Custom CA (e.g., internal enterprise CAs) | Used for internal applications, such as `*.internal` domains                           |
| **Self-Signed Certificates** | Testing and development                           | Not trusted by browsers         | N/A                                       | Quick certificates for testing or development purposes, not recommended for production |

---

### Public CA

![Alt text](/images/31-5.png)

A trusted, third-party organization that issues digital certificates for public-facing websites.

When you visit a website like `pinkbank.com`, your browser needs a way to verify that the server it’s talking to is indeed `pinkbank.com` and not someone pretending to be it. That’s where a **Certificate Authority (CA)** comes into play.

* `pinkbank.com` generates its own digital certificate (often through a **Certificate Signing Request** using tools like OpenSSL) and then gets it signed by a trusted Certificate Authority (CA) such as Let’s Encrypt to prove its authenticity.
* Seema’s browser, like most browsers, already contains the **public keys of well-known CAs**. So, it can verify that the certificate presented by `pinkbank.com` is indeed signed by Let’s Encrypt.
* This trust chain ensures authenticity. Without a CA, there would be no trusted way to confirm the server’s identity.

If a certificate were self-signed or signed by an unknown entity, Seema’s browser would show a warning because it cannot validate the certificate's authenticity.

**Important Note**
In this example, I used Let’s Encrypt because it is a popular choice for DevOps engineers, developers, and cloud engineers, as it provides free, automated SSL/TLS certificates.
> While Let’s Encrypt is widely used even in production environments, especially for public-facing services, enterprise use cases may also involve certificates from commercial Certificate Authorities (CAs) like DigiCert, GlobalSign, Entrust, or Google Trust Services — which offer advanced features like extended validation (EV), organization validation (OV), SLAs, and dedicated support.

**Examples:** DigiCert, Sectigo, Verisign, Let’s Encrypt

**Key Points:**
* ✅ Used in **production environments** and **public websites** (e.g., `https://google.com`)
* 🌍 **Trusted by all major browsers and operating systems**
* 🧾 Must comply with strict standards (WebTrust, CA/Browser Forum)
* 🏗️ Operates under **Public Key Infrastructure (PKI)** — involving keys, CSRs, and digital signatures
* ⚙️ Certificates issued by them are automatically trusted; no manual setup needed

**Use Cases:**
* E-commerce websites
* Banking portals
* Public APIs or SaaS services

---

**Public Key Infrastructure (PKI)**

PKI is a framework that manages digital certificates, keys, and Certificate Signing Requests (CSRs) to enable secure communication over networks. It involves the use of **public and private keys** to encrypt and decrypt data, ensuring confidentiality and authentication.

---

### Private CA

![Alt text](/images/31-6.png)

A CA managed **internally** by an organization for **internal or restricted use**.

Just like browsers come with a list of trusted CAs, you can manually add a CA’s public key to your trust store (e.g., in a browser or an operating system).

**Summary for Internal HTTPS Access Without Warnings**

To securely expose an internal app as `https://app1.internal` without browser warnings:

* Set up a **private Certificate Authority (CA)** and issue a TLS certificate for `app1.internal`.

* Install the **private CA’s root certificate** on all internal user machines so their browsers trust the certificate:

  * **Windows**: Use **Group Policy (GPO)** to add the CA cert to the **Trusted Root Certification Authorities** store.
  * **macOS**: Use **MDM** or manually import the root cert using **Keychain Access** → System → Certificates → Trust.
  * **Linux**: Place the CA cert in `/usr/local/share/ca-certificates/` and run:

    ```bash
    sudo update-ca-certificates
    ```

* Ensure internal DNS resolves `app1.internal` to the correct internal IP.

**Examples:**
OpenSSL, HashiCorp Vault, Smallstep CA, AWS Private CA, Cloudflare SSL

**Key Points:**
* 🔒 Used for **internal apps**, **intranets**, **Kubernetes**, **service meshes**
* 🚫 **Not trusted by browsers by default**
* 🧰 To make it trusted, add the CA’s root certificate to all systems’ or browsers’ **trust store**
* ⚙️ Automate distribution using:
  * **Windows:** Group Policy
  * **macOS:** MDM
  * **Linux:** Copy certs to `/etc/pki/ca-trust/source/anchors/` or similar via Ansible

**Use Cases:**
* Internal company dashboards (`app1.internal`)
* DevOps services (Jenkins, GitLab internal)
* Kubernetes components (etcd, kubelet, API server)
* Internal HTTPS communication

**Advantages:**
* Full control over issuance & revocation
* No dependency on public internet
* Cost-effective for internal use

---

### Self-Signed Certificate

![Alt text](/images/31-7.png)

A certificate **signed by its own private key**, not by any CA.

A **self-signed certificate** is a certificate that is **signed with its own private key**, rather than being issued by a trusted Certificate Authority (CA).

Let’s take an example:
Our developer **Shwetangi** is building an internal application named **app2**, accessible locally at **app2.test**. She wants to enable **HTTPS** to test how her application behaves over a secure connection. Since it's only for development, she generates a self-signed certificate using tools like `openssl` and uses it to enable HTTPS on **app2.test**.

#### **Typical Use Cases of Self-Signed Certificates**
* Local development and testing environments
* Internal tools not exposed publicly
* Quick prototyping or sandbox setups
* Lab or non-production Kubernetes clusters

> ⚠️ Self-signed certificates are **not trusted by browsers or clients** by default and will trigger warnings like:
> Chrome: “Your connection is not private” (NET::ERR\_CERT\_AUTHORITY\_INVALID)
> Firefox: “Warning: Potential Security Risk Ahead”

#### **Common Internal Domain Suffixes for Testing**

* `.test` — Reserved for testing and documentation (RFC 6761)
* `.local` — Often used by mDNS/Bonjour or local network devices
* `.internal` — Used in private networks or cloud-native environments (e.g., GCP)
* `.dev`, `.example` — Reserved for documentation and sometimes local use

Using these reserved domains helps avoid accidental DNS resolution on the public internet and is a best practice for local/dev setups.

**Key Points:**
* **Used only for development or testing**
* **Browsers show warnings** like “Connection is not private”
* Quick and simple to generate (using `openssl` or `mkcert`)
* Not suitable for production

**Use Cases:**
* Local testing (e.g., `app.test`, `localhost`)
* Developer sandbox environments

**Example command:**
```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365
```


```bash
# Source - https://stackoverflow.com/a
# Posted by Diego Woitasen, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-22, License - CC BY-SA 4.0

# Interactive
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365

# Non-interactive and 10 years expiration
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 3650 -nodes -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"

```
* https://stackoverflow.com/questions/10175812/how-can-i-generate-a-self-signed-ssl-certificate-using-openssl
* https://www.digitalocean.com/community/tutorials/openssl-essentials-working-with-ssl-certificates-private-keys-and-csrs

---

### **Conclusion**

Public Key Cryptography enables secure remote access, identity verification, and encrypted communication—essentials in modern infrastructure. From SSH keys to TLS certificates, understanding the flow of trust and proper key management is critical for any DevOps engineer. This foundation sets the stage for deeper topics like **mutual TLS**, **client certificates**, and **PKI systems** in production environments.