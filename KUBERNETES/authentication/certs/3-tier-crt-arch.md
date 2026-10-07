# ✅ **FULL 3-TIER PKI GUIDE USING OPENSSL ON LINUX**

This setup includes:

* **Root CA** (offline, highest trust)
* **Intermediate CA** (signs server certificates)
* **Server certificate** (for HTTPS)
* **CRL (Certificate Revocation List)**
* **OCSP (Online Certificate Status Protocol)**

Directory root will be:

```
/root/pki/
```
```bash
Root CA  →  Intermediate CA  →  Server Certificate
```
```bash
Browser/OS trusts Root CA
→ Root CA trusts Intermediate CA
→ Intermediate CA signs Server Certificate
```


---

# **Create Folder Structure (Standard RFC-style CA Layout)**

```bash
mkdir -p /root/pki/{root,intermediate,server}

# Root CA folders
mkdir -p /root/pki/root/{certs,crl,newcerts,private}
chmod 700 /root/pki/root/private
touch /root/pki/root/index.txt
echo 1000 > /root/pki/root/serial

# Intermediate CA folders
mkdir -p /root/pki/intermediate/{certs,crl,csr,newcerts,private}
chmod 700 /root/pki/intermediate/private
touch /root/pki/intermediate/index.txt
echo 2000 > /root/pki/intermediate/serial
echo 2000 > /root/pki/intermediate/crlnumber
```
#### Explanation:
```bash
###############################################
# CREATE FULL PKI DIRECTORY STRUCTURE (LINUX)
# Root CA  → /root/pki/root
# Intermediate CA → /root/pki/intermediate
# Server Certificates → /root/pki/server
###############################################

# Create the top-level PKI folders
mkdir -p /root/pki/{root,intermediate,server}

##########################################################
# ROOT CA DIRECTORY STRUCTURE (This CA is OFFLINE CA)
#
# certs       → All issued certificates
# crl         → Certificate Revocation Lists
# newcerts    → Auto-stored signed certificates
# private     → Private keys (600 permission)
# index.txt   → Database of issued certs
# serial      → Serial number for next issued cert
##########################################################

mkdir -p /root/pki/root/{certs,crl,newcerts,private}
chmod 700 /root/pki/root/private           # Protect private keys

# index.txt → certificate database (required by openssl ca)
touch /root/pki/root/index.txt

# serial → start serial number for Root CA certificates
echo 1000 > /root/pki/root/serial


##########################################################
# INTERMEDIATE CA DIRECTORY STRUCTURE
#
# csr         → Stores incoming certificate signing requests
# private     → Private key for Intermediate CA
# certs       → Signed certificates issued by Root CA
# crl         → CRLs issued by Intermediate
# newcerts    → Auto-storage for issued certificates
# index.txt   → Certificate database
# serial      → Next certificate serial number
# crlnumber   → Next CRL number
##########################################################

mkdir -p /root/pki/intermediate/{certs,crl,csr,newcerts,private}
chmod 700 /root/pki/intermediate/private   # Protect CA private key

touch /root/pki/intermediate/index.txt

# Serial number for issuing certificates
echo 2000 > /root/pki/intermediate/serial

# CRL number for issuing revocation lists
echo 2000 > /root/pki/intermediate/crlnumber
```
---

# **Create openssl.cnf for ROOT CA**

Create file:

```
/root/pki/root/openssl.cnf
```

Paste:

```ini
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /root/pki/root
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial

private_key       = $dir/private/root.key.pem
certificate       = $dir/certs/root.crt.pem

crlnumber         = $dir/crlnumber
crl               = $dir/crl/root.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 365

default_md        = sha256
preserve          = no
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
commonName              = supplied

[ req ]
default_bits        = 4096
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
default_md          = sha256

[ req_distinguished_name ]
countryName         = Country Name (2 letter code)
stateOrProvinceName = State
organizationName    = Organization
commonName          = Common Name

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ crl_ext ]
authorityKeyIdentifier=keyid:always
```

#### Explanation:

```bash
######################################################################
#  ROOT CA CONFIGURATION FILE (openssl.cnf)
#  This file defines how the Root CA behaves.
#  It controls:
#     - Directory structure
#     - Where certificates are stored
#     - Signing policies
#     - Extensions for the Root CA certificate
#     - CRL generation
######################################################################


######################################################################
# 1. Main CA Section — tells OpenSSL which CA profile to use
######################################################################
[ ca ]
default_ca = CA_default        # Load the section named CA_default


######################################################################
# 2. Default settings for the Root CA
#    This defines directories, files, CRL, database, keys, certs.
######################################################################
[ CA_default ]

# Root CA directory
dir               = /root/ca/root            # Base directory of Root CA

# Important files
certs             = $dir/certs               # Issued certificates go here
crl_dir           = $dir/crl                 # CRLs stored here
new_certs_dir     = $dir/newcerts            # New certs temporarily stored here
database          = $dir/index.txt           # Certificate database
serial            = $dir/serial              # Serial number for next cert
crlnumber         = $dir/crlnumber           # CRL number tracking file

# Private key and certificate of the Root CA
private_key       = $dir/private/ca.key      # Root CA private key
certificate       = $dir/certs/ca.crt        # Root CA certificate

# Hash algorithm
default_md        = sha256                   # Use SHA-256 always

# CRL settings
crl               = $dir/crl/ca.crl          # CRL output file
crl_extensions    = crl_ext                  # Use [crl_ext] section

# Random file for entropy storage
RANDFILE          = $dir/private/.rand

# Certificate validity period
default_days      = 7300                     # 20 years validity



######################################################################
# 3. Policy — Rules that every CSR must satisfy
######################################################################
[ policy_strict ]
countryName             = match              # CSR Country MUST match CA
stateOrProvinceName     = match              # CSR State MUST match CA
organizationName        = match              # CSR Org MUST match CA
organizationalUnitName  = optional           # Optional
commonName              = supplied           # Must be present
emailAddress            = optional           # Optional



######################################################################
# 4. Default Request Section — used when generating the Root CA cert
######################################################################
[ req ]
default_bits        = 4096                   # Size of Root CA private key
default_md          = sha256                 # Hash algorithm
distinguished_name  = req_distinguished_name # Use DN fields below
x509_extensions     = v3_ca                  # Extensions applied to CA cert



######################################################################
# 5. Distinguished Name fields (CSR prompts)
######################################################################
[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_default             = IN

stateOrProvinceName             = State or Province Name
stateOrProvinceName_default     = Rajasthan

localityName                    = Locality Name
localityName_default            = Jaipur

organizationName                = Organization Name
organizationName_default        = Pink Bank Root CA

commonName                      = Common Name
commonName_default              = Pink Bank Root Certificate Authority



######################################################################
# 6. Root CA Extensions (VERY IMPORTANT)
#    These tell browsers/clients that:
#       - this certificate IS A CA
#       - it can sign certs
#       - it can sign CRLs
#       - path length defines how many intermediates allowed
######################################################################
[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always

# This certificate *is* a CA certificate
basicConstraints = critical, CA:true, pathlen:1

# Allowed uses for this certificate
keyUsage = critical, digitalSignature, cRLSign, keyCertSign



######################################################################
# 7. CRL Extensions — applied when generating a CRL file
######################################################################
[ crl_ext ]
authorityKeyIdentifier = keyid:always
```
---

# **Generate ROOT private key + ROOT certificate**

```bash
cd /root/pki/root

# Root Key
openssl genrsa -out private/root.key.pem 4096
chmod 600 private/root.key.pem

# Root Self-Signed Certificate (valid 20 years)
openssl req -config openssl.cnf \
    -key private/root.key.pem \
    -new -x509 -days 7300 -sha256 \
    -out certs/root.crt.pem \
    -subj "/C=IN/ST=Rajasthan/O=PinkBank Root CA/CN=PinkBank Root CA"
```
#### Explanation:
```bash
# --------------------------------------------------------------------
# ROOT CA CERTIFICATE GENERATION (with explanation in comments)
# --------------------------------------------------------------------
# You MUST be inside your Root CA directory
# ~/pki/root should contain:
#   ├── certs/
#   ├── crl/
#   ├── newcerts/
#   ├── private/
#   ├── index.txt
#   ├── serial
#   └── root_openssl.cnf
# --------------------------------------------------------------------

cd ~/pki/root

# --------------------------------------------------------------------
# openssl req
#   - Creates a certificate request OR a self-signed certificate
#
# -config root_openssl.cnf
#   * Loads your Root CA configuration file.
#   * This file defines extensions, paths, DN fields, policies, etc.
#
# -key private/root.key
#   * This is your ROOT CA PRIVATE KEY.
#   * Must always stay offline and protected.
#
# -new -x509
#   -new     = create a new CSR
#   -x509    = instead of creating a CSR, create a self-signed certificate
#              (Root CA signs itself)
#
# -days 7300
#   * Certificate validity = 7300 days (20 years)
#   * Root CA is usually long-lived.
#
# -sha256
#   * Hash algorithm to use.
#   * SHA256 is industry standard for CAs.
#
# -extensions v3_ca
#   * Use the v3_ca section inside root_openssl.cnf
#   * This enables:
#       - CA:true
#       - keyCertSign
#       - cRLSign
#       - pathlen:1
#   * Without this, your cert will NOT be recognized as a CA.
#
# -out certs/root.crt
#   * Write the output ROOT CA certificate to certs/root.crt
# --------------------------------------------------------------------

openssl req -config root_openssl.cnf \
    -key private/root.key \
    -new -x509 \
    -days 7300 \
    -sha256 \
    -extensions v3_ca \
    -out certs/root.crt

# --------------------------------------------------------------------
# RESULT:
#   private/root.key   → Root CA private key
#   certs/root.crt     → Root CA self-signed certificate
#
# This certificate (root.crt) will be used to sign your Intermediate CA.
# --------------------------------------------------------------------
```
---

# **Create openssl.cnf for INTERMEDIATE CA**

Create file:

```
/root/pki/intermediate/openssl.cnf
```

Paste:

```ini
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /root/pki/intermediate
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial

private_key       = $dir/private/intermediate.key.pem
certificate       = $dir/certs/intermediate.crt.pem

crlnumber         = $dir/crlnumber
crl               = $dir/crl/intermediate.crl.pem
default_crl_days  = 180

default_md        = sha256
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
organizationName        = optional
commonName              = supplied

[ req ]
default_bits        = 4096
default_md          = sha256
distinguished_name  = req_distinguished_name
x509_extensions     = v3_intermediate_ca

[ req_distinguished_name ]
commonName          = Common Name

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```
#### Explanation:
```bash
#######################################################################
# INTERMEDIATE CA OPENSSL CONFIGURATION FILE
# This file controls how the Intermediate CA behaves:
# - Directory structure
# - Where certificates and CRLs go
# - Rules for signing server certificates
# - What policies are required for signing server CSRs
# - What extensions are added to intermediate certificates
#######################################################################

[ ca ]
# This tells OpenSSL which CA profile to load.
# When you run:  openssl ca -config openssl.cnf
# It loads the section called CA_default.
default_ca = CA_default


#######################################################################
# CA_default — Core settings for Intermediate CA
#######################################################################
[ CA_default ]
# ===== DIRECTORY STRUCTURE =====
# Path to the Intermediate CA working directory
dir               = /root/pki/intermediate

# Where signed certificates will be stored
certs             = $dir/certs

# Where CRLs will be stored
crl_dir           = $dir/crl

# Temporary directory for newly issued certs
new_certs_dir     = $dir/newcerts

# The certificate database — very important
# Tracks all issued certificates (serial number, expiration, revocation)
database          = $dir/index.txt

# Serial number for next certificate
serial            = $dir/serial


# ===== FILES USED BY THIS CA =====
# Private key of the Intermediate CA
private_key       = $dir/private/intermediate.key.pem

# Intermediate CA certificate (signed by Root CA)
certificate       = $dir/certs/intermediate.crt.pem


# ===== CRL (Certificate Revocation List) SETTINGS =====
# CRL numbering file
crlnumber         = $dir/crlnumber

# Output CRL file
crl               = $dir/crl/intermediate.crl.pem

# Validity period for CRL — default 180 days
default_crl_days  = 180


# ===== SIGNING AND GENERAL RULES =====
# Hashing algorithm used for signatures
default_md        = sha256

# Preserve DN fields? Normally "no" for intermediate CA
preserve          = no

# Which policy applies when signing CSRs
policy            = policy_loose



#######################################################################
# policy_loose — Rules for signing server certificates
#######################################################################
[ policy_loose ]
# These fields from CSR are OPTIONAL for Intermediate CA.
# A Root CA requires strict rules.
# But an Intermediate CA should allow flexible DN fields.

countryName             = optional
stateOrProvinceName     = optional
organizationName        = optional
commonName              = supplied    # MUST be provided for server certificates



#######################################################################
# req — Rules for creating the Intermediate CA CSR
#######################################################################
[ req ]
# RSA key size
default_bits        = 4096

# Hash function used when creating the CSR
default_md          = sha256

# DN fields come from this section
distinguished_name  = req_distinguished_name

# Extensions applied when generating Intermediate CA certificate
# (After being signed by Root CA)
x509_extensions     = v3_intermediate_ca



#######################################################################
# Distinguished Name fields for Intermediate CA
#######################################################################
[ req_distinguished_name ]
# We keep it minimal; only CN is required.
commonName          = Common Name



#######################################################################
# v3_intermediate_ca — Extensions for Intermediate CA certificate
#######################################################################
[ v3_intermediate_ca ]
# Identifies this certificate’s public key
subjectKeyIdentifier = hash

# Links this cert to its issuer (Root CA)
authorityKeyIdentifier = keyid:always

# VERY IMPORTANT:
# basicConstraints = CA:true → this certificate IS a CA
# pathlen:0 → It may sign ONLY server certificates.
# It CANNOT create further intermediate CAs.
basicConstraints = critical, CA:true, pathlen:0

# Key usages allowed for Intermediate CA:
# - digitalSignature → sign OCSP responses or CRLs
# - cRLSign → sign CRL
# - keyCertSign → sign server certificates
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
#This means:
#Intermediate CA can sign server certificates
#But it cannot create another subordinate CA
#(pathlen=0 enforces this)
#This preserves PKI security.
```

---

# **Generate Intermediate CA Key + CSR**

```bash
cd /root/pki/intermediate

openssl genrsa -out private/intermediate.key.pem 4096
chmod 600 private/intermediate.key.pem

openssl req -config openssl.cnf \
    -new -sha256 \
    -key private/intermediate.key.pem \
    -out csr/intermediate.csr.pem \
    -subj "/C=IN/ST=Rajasthan/O=PinkBank Intermediate CA/CN=PinkBank Intermediate CA"
```
#### Explanation:
```bash
# ---------------------------------------------------------------
# STEP 1 — Move into your Intermediate CA directory
# ---------------------------------------------------------------
# This directory contains:
#   private/      → Intermediate CA private keys
#   certs/        → Signed certificates
#   csr/          → Certificate Signing Requests
#   crl/          → Certificate Revocation Lists
#   openssl.cnf   → Intermediate CA config file
# ---------------------------------------------------------------
cd /root/pki/intermediate


# ---------------------------------------------------------------
# STEP 2 — Generate the Intermediate CA private key (4096-bit)
# ---------------------------------------------------------------
# This is the MOST sensitive key.
# Whoever controls this key can sign certificates for your PKI.
# - 4096-bit RSA is strong enough for long-term CA usage.
# - Output is saved under private/intermediate.key.pem
# ---------------------------------------------------------------
openssl genrsa -out private/intermediate.key.pem 4096

# Make the key readable ONLY by root (VERY IMPORTANT)
chmod 600 private/intermediate.key.pem


# ---------------------------------------------------------------
# STEP 3 — Generate Intermediate CA CSR (Certificate Signing Request)
# ---------------------------------------------------------------
# The CSR includes:
#   • Public key of the Intermediate CA
#   • Identifying information (DN fields)
#   • It does NOT include the private key
#
# The Root CA will SIGN this CSR to create:
#      intermediate.crt.pem
#
# -config openssl.cnf  
#     → Uses your Intermediate CA config file.
#       This file contains all important fields like:
#           [req]                     – DN + extensions
#           [req_distinguished_name] – What fields are needed
#           [v3_intermediate_ca]     – Extensions for Intermediate CA
#
# -subj "/C=IN/.../CN=PinkBank Intermediate CA"
#     → Overrides interactive DN prompting.
#
# -new -sha256  
#     → Create a new CSR using SHA-256 hash.
# ---------------------------------------------------------------
openssl req -config openssl.cnf \
    -new -sha256 \
    -key private/intermediate.key.pem \
    -out csr/intermediate.csr.pem \
    -subj "/C=IN/ST=Rajasthan/O=PinkBank Intermediate CA/CN=PinkBank Intermediate CA"

# ---------------------------------------------------------------
# After this step you will have:
#   private/intermediate.key.pem   → Intermediate CA private key
#   csr/intermediate.csr.pem       → CSR waiting to be signed by ROOT CA
#
# NEXT STEP:
#   The Root CA signs the CSR with:
#       openssl ca -config /root/pki/root/openssl.cnf ...
#
# This produces the final Intermediate certificate:
#   certs/intermediate.crt.pem
# ---------------------------------------------------------------
```
---

# **Sign Intermediate CA CSR using ROOT CA**

```bash
cd /root/pki/root

openssl ca -config openssl.cnf \
    -extensions v3_intermediate_ca \
    -days 3650 -notext -md sha256 \
    -in ../intermediate/csr/intermediate.csr.pem \
    -out ../intermediate/certs/intermediate.crt.pem
```
#### Explanation:
```bash
# Move inside Root CA directory
cd /root/pki/root

# Root CA signs the Intermediate CA CSR
openssl ca \
    -config openssl.cnf \
        # Use Root CA's openssl.cnf (contains CA_default, policies, extensions)
    -extensions v3_intermediate_ca \
        # Apply the 'v3_intermediate_ca' extensions from intermediate's config
        # These extensions include:
        #   CA:true
        #   pathlen:0   -> Intermediate cannot sign another intermediate
        #   Key usage: digitalSignature, cRLSign, keyCertSign
    -days 3650 \
        # Intermediate CA valid for 10 years
        # Root CA is usually valid 20 years, intermediate 10 years
    -notext \
        # Do not include human-readable text inside certificate
        # Only clean ASN.1 structure
    -md sha256 \
        # Use SHA-256 hash for signing
    -in ../intermediate/csr/intermediate.csr.pem \
        # The CSR created using Intermediate's private key
        # The Root CA will read and sign this request
    -out ../intermediate/certs/intermediate.crt.pem
        # Final signed Intermediate CA certificate
```
* What Happens When You Run openssl ca?
  * OpenSSL CA engine performs:
    1. Loads Root CA openssl.cnf
       From:
       `/root/pki/root/openssl.cnf`
       Important sections used:
        ```
            [ ca ]
            [ CA_default ]
            [ policy_strict ]
            database = index.txt
            serial = serial
        ```
    2. Reads Root CA Private Key
       File:
       `/root/pki/root/private/root.key.pem`
    3. Reads Intermediate CSR
       File:
       `/root/pki/intermediate/csr/intermediate.csr.pem`
    4. Applies v3_intermediate_ca extensions
       From the Intermediate CA config:
        ```
        [ v3_intermediate_ca ]
        subjectKeyIdentifier = hash
        authorityKeyIdentifier = keyid:always
        basicConstraints = critical, CA:true, pathlen:0
        keyUsage = critical, digitalSignature, cRLSign, keyCertSign
        ```
        This ensures:
        ✔ It is a CA
        ✔ But it cannot create further Intermediate CAs
        ✔ Only server + client certs

    5. Updates Root CA index + serial files
       The CA database files are updated:
        ```bash
        index.txt        → log of all issued certificates
        serial           → increments certificate number
        ```
    6. Produces the final Intermediate CA certificate
       Saved to:
       `/root/pki/intermediate/certs/intermediate.crt.pem`
       Create CA chain:

* **Verify the Intermediate CA Certificate**
    ```bash
    openssl x509 -noout -text -in /root/pki/intermediate/certs/intermediate.crt.pem

    Check for:
    ✔ CA:TRUE
    ✔ pathlen:0
    ✔ KeyCertSign
    ✔ CRLSign
    ✔ Signed by: Root CA
    ✔ Validity: 10 years
    ```

* **Verify Chain (Root → Intermediate)**
    ```bash
    openssl verify -CAfile /root/pki/root/certs/root.crt \
        /root/pki/intermediate/certs/intermediate.crt.pem

    intermediate.crt.pem: OK
    ```

* **
```bash
cat /root/pki/intermediate/certs/intermediate.crt.pem \
    /root/pki/root/certs/root.crt.pem \
    > /root/pki/intermediate/certs/ca-chain.crt.pem
```
#### Explanation:
```bash
###############################################################
#  PURPOSE OF THIS COMMAND
#  ------------------------
#  A server or client does NOT trust an Intermediate CA alone.
#  It must also be able to trace the chain → Intermediate → Root.
#
#  Therefore, we create a bundle file that contains:
#     1. Intermediate certificate  (first)
#     2. Root certificate          (second)
#
#  This "CA chain" file is given to:
#     ✔ Web servers (Apache, Nginx, HAProxy)
#     ✔ Applications needing a full trust chain
#     ✔ Clients that need to verify server certs
#
#  ORDER IS IMPORTANT:
#     Intermediate first, Root last.
#
#  WHY THIS ORDER?
#     Because the certificate presented first must match the
#     "issuer" of your server certificate. The Root is the final
#     trust anchor, so it goes at the end.
###############################################################

# Create CA Chain file from Intermediate + Root
cat /root/pki/intermediate/certs/intermediate.crt.pem \
    /root/pki/root/certs/root.crt.pem \
    > /root/pki/intermediate/certs/ca-chain.crt.pem


###############################################################
#  WHAT THIS FILE LOOKS LIKE INTERNALLY?
#  -------------------------------------
#  -----BEGIN CERTIFICATE-----
#     (Intermediate CA certificate)
#  -----END CERTIFICATE-----
#
#  -----BEGIN CERTIFICATE-----
#     (Root CA certificate)
#  -----END CERTIFICATE-----
#
#  This combined file is safe to distribute publicly.
#  It contains NO private keys.
###############################################################

```
---

# **Generate SERVER key + CSR**

```bash
cd /root/pki/server

openssl genrsa -out server.key.pem 2048

openssl req -new -sha256 \
   -key server.key.pem \
   -out server.csr.pem \
   -subj "/CN=localhost"
```
### Explanation:
```bash
###############################################
# SERVER CERTIFICATE GENERATION — FULL THEORY #
###############################################

# Step 1: Go to server directory
# --------------------------------
# This is where we store:
#   - server.key.pem  → Private key
#   - server.csr.pem  → Certificate Signing Request
#   - server.crt.pem  → Final server certificate (after signing)
#
cd /root/pki/server


# Step 2: Generate server private key
# ------------------------------------
# openssl genrsa
#   - Generates an RSA private key
#
# -out server.key.pem
#   → Save the private key file
#
# 2048
#   → Key size. 2048 is enough for server certs.
#
# NOTE:
#   - This key must remain SECRET.
#   - Never share this file.
#
openssl genrsa -out server.key.pem 2048



# Step 3: Generate CSR (Certificate Signing Request)
# ---------------------------------------------------
# openssl req
#   -new          → Create new CSR
#   -sha256       → Hash algorithm
#   -key          → Use this private key
#   -out          → Save CSR file
#
# -subj "/CN=localhost"
#   → DN (Distinguished Name)
#   → CN = Common Name of server
#
# For real websites:
#   -subj "/CN=pinkbank.com"
#
# The CSR does NOT become a certificate yet.
# The intermediate CA will sign it.
#
openssl req -new -sha256 \
   -key server.key.pem \
   -out server.csr.pem \
   -subj "/CN=localhost"


##################################################
# RESULT:
#   • server.key.pem  → server private key
#   • server.csr.pem  → send this to your CA
#
# NEXT STEP:
#   Your Intermediate CA will sign this CSR:
#   openssl ca -config openssl.cnf -extensions server_cert ...
##################################################
```
---

# **Create server_cert.ext for SAN**

File:

```
/root/pki/server/server_cert.ext
```

```
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = pinkbank.local
IP.1 = 127.0.0.1
```
#### Explanation:-
```bash
# ---------------- SERVER CERTIFICATE EXTENSIONS ----------------
# This file defines how the SERVER certificate must behave.
# It is used when signing the server.csr.pem with the Intermediate CA.

# 1. authorityKeyIdentifier
#    This links the server certificate to the CA that signed it.
#    keyid    = include CA key identifier
#    issuer   = include issuer (CA) name
authorityKeyIdentifier = keyid,issuer

# 2. basicConstraints
#    CA:FALSE → This MUST be FALSE for all server certificates.
#    It ensures the server certificate cannot sign other certificates.
basicConstraints = CA:FALSE

# 3. keyUsage
#    What cryptographic operations this certificate is allowed to perform.
#    digitalSignature → for TLS handshake signatures
#    keyEncipherment  → used for encrypting session keys (RSA)
keyUsage = digitalSignature, keyEncipherment

# 4. extendedKeyUsage
#    Server certificates must include serverAuth for HTTPS/TLS.
#    (clientAuth is used for mTLS, not needed here)
extendedKeyUsage = serverAuth

# 5. subjectAltName (SAN)
#    SAN is REQUIRED by browsers. CN alone is ignored.
#    Add ALL DNS names and IPs your server will use.
subjectAltName = @alt_names


# ---------------- ALTERNATE NAMES SECTION ----------------
[alt_names]
# DNS names allowed for HTTPS
DNS.1 = localhost
DNS.2 = pinkbank.local

# IP addresses allowed
IP.1  = 127.0.0.1
```


---

# **Sign SERVER certificate using Intermediate CA**

```bash
openssl x509 -req -in server.csr.pem \
    -CA /root/pki/intermediate/certs/intermediate.crt.pem \
    -CAkey /root/pki/intermediate/private/intermediate.key.pem \
    -CAcreateserial \
    -out server.crt.pem \
    -days 825 -sha256 \
    -extfile server_cert.ext
```
#### Explanation:
```bash
# -------------------------------
# SIGN SERVER CERTIFICATE USING INTERMEDIATE CA
# -------------------------------
# This command converts the CSR (server.csr.pem) into a signed certificate (server.crt.pem)
# The intermediate CA signs it, NOT the root CA.
# -------------------------------

openssl x509 -req \                    # Convert CSR → X.509 certificate
    -in server.csr.pem \              # Your server CSR
    -CA /root/pki/intermediate/certs/intermediate.crt.pem \       # Intermediate CA certificate
    -CAkey /root/pki/intermediate/private/intermediate.key.pem \  # Intermediate CA private key (used to sign)
    -CAcreateserial \                 # Auto-create “intermediate.srl” for serial number if missing
    -out server.crt.pem \             # Output: final server certificate
    -days 825 \                       # Validity period (max recommended for TLS certs)
    -sha256 \                         # Signing hash algorithm
    -extfile server_cert.ext          # Extensions file (SAN, keyUsage, EKU, CA:false)

# -------------------------------
# THEORY / WHY EACH PARAMETER IS USED
# -------------------------------
# -req:
#   Means we are processing a CSR (Certificate Signing Request).
#
# -in server.csr.pem:
#   The CSR created earlier using the server private key.
#
# -CA … -CAkey …:
#   The certificate and private key of the Intermediate CA that will sign this request.
#
# -CAcreateserial:
#   Creates a serial number file if none exists. Required for keeping correct numbering.
#
# -days 825:
#   Max lifetime recommended by modern browsers for leaf/server certificates.
#
# -sha256:
#   Industry-standard hashing algorithm for signing certificates.
#
# -extfile server_cert.ext:
#   EXTREMELY IMPORTANT.
#   This file defines:
#       • CA:FALSE → This is NOT a CA certificate
#       • keyUsage → What operations the key can do
#       • extendedKeyUsage → serverAuth required for HTTPS
#       • subjectAltName → Modern browsers use SAN, not CN
#
# Output (server.crt.pem) is your final HTTPS server certificate.
# You will combine it later with:
#       server.crt.pem + intermediate CA chain (ca-chain.crt.pem)
# for use in Apache, Nginx, Flask, etc.
```
or 

```bash
cd /root/pki/intermediate

openssl ca -config openssl.cnf \
    -extensions server_cert \
    -days 825 -notext -md sha256 \
    -in ../server/server.csr.pem \
    -out ../server/server.crt.pem
```
`vim /root/pki/intermediate/openssl.cnf`

```bash
#APPEND
[ server_cert ]
# Basic server certificate
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "PinkBank Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
```
```bash
openssl verify -CAfile certs/ca-chain.crt.pem ../server/server.crt.pem
../server/server.crt.pem: OK
```


---
# **Your final certificate chain should be:**

```
server.crt.pem
intermediate.crt.pem
```

For Nginx/Apache use **full-chain**:

```
cat server.crt.pem /root/pki/intermediate/certs/intermediate.crt.pem > fullchain.pem
```

---

# **Install Root CA into Linux trust store**

```bash
# Copy your Root CA certificate into the system trust store
# ----------------------------------------------------------
# /usr/local/share/ca-certificates/    → place custom CA files here
# filename must end with .crt

sudo cp /root/pki/root/certs/root.crt.pem \
        /usr/local/share/ca-certificates/pinkbank-root.crt    # ← rename as .crt

# Update the CA store
# ----------------------------------------------------------
# This command reads all *.crt in /usr/local/share/ca-certificates/
# and writes them into: /etc/ssl/certs/ca-certificates.crt

sudo update-ca-certificates

# 1. You copy your Root CA into OS trust store
#    → This makes Linux trust any certificate signed by your Root CA.

# 2. update-ca-certificates:
#    - Scans /usr/local/share/ca-certificates/*.crt
#    - Adds them into the system-wide bundle at: /etc/ssl/certs/ca-certificates.crt
#    - Generates hashed symlinks in /etc/ssl/certs/
#    - Makes OpenSSL, curl, wget, Nginx, Git, Python, Docker, etc TRUST your CA.

# After this step:
#    ✔ curl https://localhost --cacert root.crt is NOT needed
#    ✔ Browsers (Firefox needs manual import, Chrome uses system store)
#    ✔ Your server cert + intermediate will validate properly

```

---

# **Install in Windows (Trusted Root Certification Authorities)**

1. Open **Run → mmc**
2. File → Add/Remove Snap-in
3. Choose **Certificates** → *Computer account*
4. Expand:

```
Trusted Root Certification Authorities → Certificates
```

5. Right-click → **Import**
6. Select `root.crt.pem`
7. Finish → Restart browser

To trust intermediate:
```
Intermediate Certification Authorities → Certificates → Import
```

* Verify Installation
  * Using Chrome/Edge 
    ```bash
    #On Chrome/edge
    chrome://settings/security
    #Or open any HTTPS site signed by your CA.
    #Click lock icon → Certificate
    #You should see a chain:
    PinkBank Root CA
        PinkBank Intermediate CA
            server.localhost
    ```
  * Using PowerShell
    ```bash
    Get-ChildItem Cert:\LocalMachine\Root | findstr "PinkBank"
    Get-ChildItem Cert:\LocalMachine\CA   | findstr "PinkBank"
    ```
---

# **Run Flask with your new cert**

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    return "Flask HTTPS OK!"


if __name__ == '__main__':
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True,
        ssl_context=("server.crt", "server.key")
    )

```

---

# **Your browser will now show HTTPS ✓ Trusted (NO warnings)**

Because **root CA is trusted**, **intermediate is chained**, **SAN is present**.

---

### There are TWO DIFFERENT CHAIN FILES

* **CA Chain (Used for verifying, NOT for webservers)**
  * Contains only: Intermediate CA, Root CA, NOT the server certificate.
  * This file is used NOT by webservers.
    ```bash
    cat intermediate.crt.pem root.crt.pem > ca-chain.crt.pem
    ```
  * This file is used by:
    * Applications need the trust chain
    * Certificate verification tools
    * Other servers that trust your Intermediate CA
    * OpenSSL verify
    * Applications verifying server certs
    * Client software
    * curl with --cacert
        ```bash
        curl --cacert root.crt.pem https://localhost
        ```
    * `ca-chain.pem`
        ```bash
        -----BEGIN CERTIFICATE-----
        (intermediate certificate)
        -----END CERTIFICATE-----

        -----BEGIN CERTIFICATE-----
        (root certificate)
        -----END CERTIFICATE-----
        ```
    * VERIFYING certificates
      Clients/tools use ca-chain.pem to check if a server certificate is valid.
        ```bash
        openssl verify -CAfile ca-chain.pem server.crt.pem
        ```
    * `curl / wget / python clients`
        ```bash
        curl --cacert ca-chain.pem https://localhost
        ```

* **FULLCHAIN (Used by Nginx & Apache)**
  * Contains: Server certificate → MUST be first, Intermediate certificate(s) → second, Not Root certificate → NEVER included.
  * Used by Web Servers — Nginx/Apache
    ```bash
    fullchain.pem = server.crt.pem + intermediate.crt.pem
    ```
  ```bash
  cat server.crt.pem \
    /root/pki/intermediate/certs/intermediate.crt.pem \
    > fullchain.pem
  ```
  * This file is sent to clients (browser, curl, etc.)
  * Clients verify the chain using their own local Root CA store.
  * Browsers expect the server to present the entire cert chain starting from the server certificate
  * Application send the crts in fullchain to the client
  * WHY ROOT CERTIFICATE IS NOT INCLUDED?
    * Browsers, Linux, Windows, macOS already store trusted root CAs.
        • Windows → Trusted Root Certification Authorities
    • Linux → /etc/ssl/certs or /usr/local/share/ca-certificates
    • macOS → Keychain Access
    * The client/OS browser already has root.crt in its system trust store.
    * If you send root cert from server → security weakness

* **Verify server chain manually**
    ```bash
    openssl verify -CAfile root.crt.pem fullchain.pem
    
    fullchain.pem: OK
    ```
    * Your server cert → intermediate cert → root cert = VALID chain.


---
```bash
└── /root/ca
    ├── root
    │     ├── private/          (Root CA private key)
    │     ├── certs/            (Root CA certificate)
    │     ├── newcerts/         (Where signed certs go)
    │     ├── crl/              (CRLs)
    │     ├── index.txt         (DB of signed certs)
    │     ├── serial            (Certificate serial numbers)
    │     └── openssl.cnf       (Root CA configuration)
    │
    └── intermediate
          ├── private/
          ├── certs/
          ├── csr/
          ├── newcerts/
          ├── crl/
          ├── index.txt
          ├── serial
          ├── openssl.cnf
```
---

### Nginx Full HTTPS Configuration

`/etc/nginx/sites-available/pinkbank.conf`
```bash
###############################################
# NGINX HTTPS CONFIG FOR SELF-SIGNED ROOT + INTERMEDIATE + SERVER CERT
###############################################

server {
    listen 80;
    server_name localhost pinkbank.local;

    # Redirect all HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name localhost pinkbank.local;

    # --- SSL Certificate Files ---
    ssl_certificate      /etc/ssl/pinkbank/fullchain.pem;   # server + intermediate
    ssl_certificate_key  /etc/ssl/pinkbank/server.key.pem;  # server private key

    # --- (Optional) Path to Root CA for client verification ---
    # ssl_client_certificate /etc/ssl/pinkbank/root.crt.pem;
    # ssl_verify_client optional;

    # --- Security and TLS settings ---
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;

    # --- OCSP Stapling (optional but recommended) ---
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/ssl/pinkbank/fullchain.pem;

    # --- Your application root ---
    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
`/etc/ssl/pinkbank/`

| File                 | Description                           |
| -------------------- | ------------------------------------- |
| server.key.pem       | YOUR server private key               |
| server.crt.pem       | Server certificate                    |
| intermediate.crt.pem | Intermediate CA                       |
| fullchain.pem        | server.crt.pem + intermediate.crt.pem |
| root.crt.pem         | Root CA certificate (trusted locally) |

`fullchain.pem`
```bash
-----BEGIN CERTIFICATE-----   (server.crt.pem)
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----   (intermediate.crt.pem)
-----END CERTIFICATE-----
```

---

### Apache Full HTTPS Configuration (mod_ssl)
`/etc/httpd/conf.d/pinkbank.conf`(CentOS/RHEL)
`/etc/apache2/sites-available/pinkbank.conf` (Ubuntu)
```bash
###############################################
# APACHE HTTPS CONFIG FOR ROOT + INTERMEDIATE + SERVER CERT
###############################################

<VirtualHost *:80>
    ServerName localhost
    ServerAlias pinkbank.local
    Redirect / https://localhost/
</VirtualHost>

<VirtualHost *:443>
    ServerName localhost
    ServerAlias pinkbank.local

    DocumentRoot /var/www/html

    # --- SSL Certificates ---
    SSLEngine on
    SSLCertificateFile      /etc/ssl/pinkbank/fullchain.pem     # server + intermediate
    SSLCertificateKeyFile   /etc/ssl/pinkbank/server.key.pem     # server private key
    SSLCertificateChainFile /etc/ssl/pinkbank/intermediate.crt.pem

    # --- TLS settings ---
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLHonorCipherOrder on

    # --- Optional OCSP stapling ---
    SSLUseStapling on
    SSLStaplingResponderTimeout 5
    SSLStaplingReturnResponderErrors off
    SSLStaplingCache shmcb:/var/run/ocsp(128000)

    <Directory "/var/www/html">
        AllowOverride All
        Require all granted
    </Directory>

</VirtualHost>
```
* Enable site (Debian/Ubuntu only)
    ```bash
    sudo a2ensite pinkbank.conf
    sudo systemctl reload apache2
    ```
* Restart Apache
    ```bash
    sudo systemctl restart httpd     # CentOS/RHEL
    sudo systemctl restart apache2   # Ubuntu/Debian
    ```
