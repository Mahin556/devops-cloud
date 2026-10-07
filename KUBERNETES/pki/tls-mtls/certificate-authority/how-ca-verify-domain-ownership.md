### How a Certificate Authority (CA) Validates Domain Ownership
* Before giving you an SSL certificate, a CA must confirm that **you control the domain**.
* They use several validation methods:

**1. HTTP Challenge**
  * The CA gives you a unique token (file).
  * You must upload it to your website at a specific URL like:
    ```
    http://yourdomain.com/.well-known/acme-challenge/12345token
    ```
  * If the CA can access that file, it proves you control the web server → domain ownership confirmed.


**2. DNS Challenge**
  * CA gives you a token.
  * You must add it as a **TXT record** in your domain's DNS zone.
  * Example DNS record:
    ```
    _acme-challenge.yourdomain.com   TXT   "random-verification-token"
    ```
  * Only the domain owner can edit DNS records.
  * So if the token appears in DNS → ownership verified.


**3. Email Verification**
  * CA sends a verification link to approved admin emails, such as:
    ```
    admin@yourdomain.com
    administrator@yourdomain.com
    webmaster@yourdomain.com
    hostmaster@yourdomain.com
    postmaster@yourdomain.com
    ```
  * You must click the verification link.
  * Access to admin email means you control the domain.
