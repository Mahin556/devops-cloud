### External Identity Providers

Kubernetes can delegate authentication to external identity systems:

* **OIDC (OpenID Connect)** — Works with providers like Google, GitHub, Azure AD, Okta
* **LDAP/Kerberos** — Often used in enterprise environments. MS AD is an example.
* **Webhook Token Authentication** — Delegates auth to a custom service via HTTP

> LDAP/Kerberos are not built into Kubernetes natively. Instead, they are typically integrated via custom authentication plugins or webhooks.

✅ These methods offer **centralized identity management**, **SSO**, and **better compliance**.

---

**The API server uses appropriate flags like:**

**OIDC (OpenID Connect) Flags:**

```bash
--oidc-issuer-url=<issuer-url>
--oidc-client-id=<client-id>
--oidc-username-claim=<claim>          # Optional, defaults to "sub"
--oidc-groups-claim=<claim>            # Optional, to extract user groups
--oidc-ca-file=<ca-file>                # Optional, custom CA bundle for the issuer
```

---

**Webhook Token Authentication Flag:**

```bash
--authentication-token-webhook-config-file=/path/to/webhook-config.yaml
```

* This points to the webhook configuration YAML file that defines the external HTTP webhook endpoint and client configuration.
* The webhook handles token validation and user identity resolution.

---

**LDAP/Kerberos:**

* Kubernetes API server **does not have native flags for LDAP or Kerberos**.
* LDAP/Kerberos authentication is usually implemented by integrating the API server with an **external proxy or authentication gateway** that performs LDAP/Kerberos authentication before forwarding requests.
* Alternatively, LDAP/Kerberos can be combined with **Webhook Token Authentication** if you implement a custom webhook service that validates tokens based on LDAP/Kerberos.

---

**Authentication via External Identity Providers**
Regardless of the identity provider being used—whether it's Google, Microsoft, Ping, Okta, or any other service—it is ultimately the **Kubernetes API server** that performs authentication. The external identity provider simply acts as the **identity store** or authentication mechanism, issuing credentials or tokens that Kubernetes validates.

When Kubernetes integrates with an external identity provider (such as an OpenID Connect (OIDC) or LDAP-based service), it delegates authentication to that system. The flow typically works like this:
1. **User Logs In**: The user authenticates against the external identity provider.
2. **Token Issuance**: The identity provider issues a token (such as a JWT for OIDC).
3. **Token Validation by API Server**: Kubernetes receives the token in an API request and verifies it using the configured authentication method.
4. **User Access Granted or Denied**: Based on the authentication result, Kubernetes either grants or denies access.

This approach enhances **security and scalability**, as organizations can centralize authentication across multiple applications while Kubernetes simply acts as the verifier. It also enables features like **single sign-on (SSO)** and **multi-factor authentication (MFA)**, which wouldn't be possible with Kubernetes' built-in authentication methods.

---

> **Note:** No matter which authentication method is used — static files, tokens, certificates, or external identity — it is **always the Kubernetes API server that performs authentication**. Every request passes through it, and it is responsible for verifying identity.