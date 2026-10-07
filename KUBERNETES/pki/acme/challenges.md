Here’s a deeper look at the three common ACME challenge types and how they compare.

**Small terminology note:** the ACME server presents available challenges for each domain; the client chooses one, fulfills it, and then tells the server to validate. The CA then checks from the public internet.

---

### HTTP-01
**How it works**
- The client computes a **key authorization**:
  `token + "." + base64url(thumbprint(accountKey))`
- It serves that value at:
  `http://<domain>/.well-known/acme-challenge/<token>`
- The CA fetches that URL on **port 80** and checks the content.

**Pros**
- Simple and widely supported.
- Works with almost any web server.
- No DNS API needed.

**Cons**
- Requires the domain to be publicly reachable on port 80.
- **Does not support wildcard certificates** (`*.example.com`).
- Can break with CDNs, load balancers, redirects, or firewall rules if not configured carefully.
- Redirects are usually allowed, but they must stay within HTTP/HTTPS and not go to unusual ports.

**Best for:** normal public websites and APIs where port 80 is available.

---

### DNS-01
**How it works**
- The client creates a TXT record at:
  `_acme-challenge.<domain>`
- The value is:
  `base64url(SHA256(keyAuthorization))`
- The CA queries authoritative DNS for that TXT record and verifies the value.

**Pros**
- **Only challenge type that supports wildcard certificates.**
- Does not require any inbound HTTP/HTTPS ports.
- Works well for internal services, as long as the domain’s DNS is publicly resolvable.
- Can be fully automated through DNS provider APIs.

**Cons**
- Requires DNS control and, for automation, a DNS provider API.
- DNS propagation delays can cause failures.
- Multiple TXT records may be needed if you request both `example.com` and `*.example.com` at the same time.
- Manual updates are error-prone.

**Best for:** wildcard certs, private services, and environments where opening port 80/443 is not desirable.

---

### TLS-ALPN-01
**How it works**
- The client listens on **port 443** and responds to a special TLS handshake.
- It uses the ALPN protocol `acme-tls/1`.
- It presents a self-signed certificate containing a special `acmeIdentifier` extension with a SHA-256 digest of the key authorization.
- The CA connects to port 443, negotiates `acme-tls/1`, and validates that certificate.

**Pros**
- No HTTP service required.
- Useful when only port 443 is exposed.
- Can work well in some container or reverse-proxy setups.

**Cons**
- Requires control of port 443 and the TLS stack.
- **Does not support wildcard certificates.**
- Can conflict with an existing web server unless SNI routing or a separate listener is configured.
- Less commonly used than HTTP-01 and DNS-01.

**Best for:** systems that only expose TLS on 443 and cannot use HTTP-01 or DNS-01.

---

### Quick comparison

| Challenge | Port | Wildcard? | Requires DNS API? | Public inbound port? |
|---|---:|---:|---:|---:|
| HTTP-01 | 80 | No | No | Yes, port 80 |
| DNS-01 | 53 | Yes | Usually | No |
| TLS-ALPN-01 | 443 | No | No | Yes, port 443 |

---

### Practical notes
- The CA validates from **multiple network vantage points**, so local hosts-file tricks or split-horizon DNS will not work.
- **CAA records** are checked before issuance, so make sure your DNS allows the CA you’re using.
- For HTTP-01, make sure the challenge path bypasses caches, CDN rewrites, and forced HTTPS redirects that might break validation.
- For DNS-01, keep TTLs low during validation and wait for propagation before telling the ACME server to check.
- Deprecated challenges like **TLS-SNI-01/02** should not be used.

If you want, I can show concrete examples for Certbot, acme.sh, or cert-manager.