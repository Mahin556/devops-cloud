# SSH Key Exchange and Authentication — Full Explanation

## 🧩 Step 0: Understanding the Basics

Before a secure SSH connection can happen, two key things must be true:

1. **Client (Sema)** and **Server (Ubuntu VM)** must **authenticate each other**.

   * Client = the one initiating SSH (`ssh user@server`)
   * Server = the one accepting SSH connections

2. **All communication must be encrypted** so no one can read or modify data in transit.

---

## 🧠 Step 1: Key Pair — Public and Private Keys

* Sema (the client) has:

  * A **private key** — kept secret and never leaves her machine.
  * A **public key** — can be safely shared.

The **server stores** a copy of Sema’s **public key** (in `/home/username/.ssh/authorized_keys`).

So when Sema connects:

* Her private key stays with her.
* The public key is already on the server.

---

## ⚙️ Step 2: SSH Connection Initiation

When Sema runs:

```bash
ssh sema@ubuntu-server
```

→ The SSH handshake begins.

And here’s the important part:

> 🔒 Encryption happens **right at the start** — even before authentication.

That means all authentication information (passwords, keys, etc.) is sent **inside an encrypted tunnel**.

---

## 🔄 Step 3: Session Key Creation (Encryption Setup)

At the beginning, both sides (Sema and server) **jointly create a session key** — a **temporary symmetric key** used for this connection only.

### 🔹 What is a session key?

A **symmetric key** that both client and server use:

* One key for both encryption and decryption.
* Faster and lighter than asymmetric encryption.

Example:

```
Sema encrypts data → Server decrypts using same session key.
Server encrypts → Sema decrypts with same key.
```

---

## 🧮 Step 4: How the Session Key Is Generated

Now comes the smart part — **Diffie-Hellman Key Exchange (DH or ECDH)**.

### How it works:

1. Both sides generate **temporary (ephemeral)** key pairs.
2. They exchange **only the public parts**.
3. Each side uses **its private key + the other’s public key** to calculate a **shared secret**.
4. That shared secret mathematically results in the **same session key** on both ends.

➡️ Neither side ever **sends** the session key over the network.
➡️ It’s derived independently using math — this is the **“magic” of Diffie-Hellman**.

So:

* **Sema’s private ephemeral key** + **Server’s public ephemeral key** = session key
* **Server’s private ephemeral key** + **Sema’s public ephemeral key** = same session key

Thus:

> 🧠 The session key is the same on both sides — without ever being transmitted.

---

## 🧱 Step 5: Encryption Tunnel Established

Once that session key is created:

* A secure encrypted tunnel is formed between Sema and the server.
* From now on, **all communication**, including authentication, happens securely inside this tunnel.

So now:

> Even if someone intercepts packets, they see only encrypted data — not usernames, passwords, or keys.

---

## 🧾 Step 6: Server Authentication

Now that the channel is encrypted, the **client must verify that the server is genuine** (not an attacker).

How?

* The server presents its **public host key fingerprint** to Sema.

The fingerprint is a short unique hash (like a digital signature) of the server’s public key.

Example prompt Sema might see:

```
The authenticity of host 'ubuntu-server (10.0.0.1)' can't be established.
ED25519 key fingerprint is SHA256:AbCdEfGh...
Are you sure you want to continue connecting (yes/no)?
```

---

## 🧾 Step 7: Host Key Verification (Server Trust Methods)

Sema now has to decide: *Do I trust this server’s fingerprint?*
Here are all the ways she can verify it:

### 1. **Trust on First Use (TOFU)**

* Sema accepts the fingerprint once manually (presses “yes”).
* SSH saves the server’s public key in:

  ```
  ~/.ssh/known_hosts
  ```
* Future connections check against this file.

### 2. **Phone a Friend**

* Sema asks a colleague who already has SSH access to verify the fingerprint on the actual server.

### 3. **Out-of-Band Verification**

* Sema logs into the VM via console or cloud dashboard and checks the server’s fingerprint directly.

### 4. **Ansible Automation**

* Using Ansible, the admin can **preload the known host fingerprints** for all servers.
* Then, when Sema connects, she won’t see the “unknown host” prompt.

### 5. **Manual Preload**

* Sema can manually add a server’s public key and fingerprint to her `known_hosts` file before connecting.

### 6. **Centralized Trust Model (Enterprise)**

* In large organizations, a **Certificate Authority (CA)** verifies server identities using SSH certificates.

---

## 🧩 Step 8: Client Authentication (After Server Trust)

Once Sema trusts the server, now **the server must verify Sema**.

* The server checks whether Sema’s **public key** is in its `authorized_keys` file.
* If yes:

  1. The server sends a **challenge** (a random string).
  2. Sema’s SSH client encrypts that challenge with her **private key**.
  3. The server decrypts it with Sema’s **public key**.
  4. If it matches → authentication succeeds.

✅ Sema is authenticated.

---

## 🔐 Step 9: Secure Communication

At this point:

* Both sides are authenticated.
* The tunnel is encrypted with the **session key**.
* Data flows securely in both directions.

Even if someone captures the traffic, they **cannot decrypt it**, because:

* The session key was never sent.
* The private keys are never shared.

---

## 🔁 Step 10: Subsequent Connections

Next time Sema connects:

* SSH finds the server’s fingerprint already stored in `known_hosts`.
* No verification prompt appears unless:

  * The server’s key changes (e.g., reinstalled or compromised).

Then SSH warns:

```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

This prevents **man-in-the-middle attacks**.
