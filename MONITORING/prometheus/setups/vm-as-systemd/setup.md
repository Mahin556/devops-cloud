Yes — if you mean **the complete Prometheus installation steps from the transcript**, here is the process in a clean, engineer-friendly format.

# Prometheus Installation — Complete Engineer Steps

The transcript covers two stages:

1. **Install and test Prometheus manually**
2. **Configure Prometheus properly as a systemd service**

The second approach is the one you would normally use on a Linux server. 

---

# Part 1 — Download and Install Prometheus

## Step 1: Download Prometheus

First, go to the Prometheus download page and obtain the appropriate Linux binary URL.

Then download it:

```bash
wget <PROMETHEUS-DOWNLOAD-URL>
```

The transcript uses `wget` to download the Prometheus tar archive. 

Check the downloaded file:

```bash
ls -lh
```

You should see something similar to:

```text
prometheus-<version>.linux-amd64.tar.gz
```

---

# Step 2: Extract the archive

```bash
tar xvf prometheus-<version>.linux-amd64.tar.gz
```

Then:

```bash
ls -lh
```

You should now have a directory such as:

```text
prometheus-<version>.linux-amd64/
```

Move into it:

```bash
cd prometheus-<version>.linux-amd64/
```

The extracted directory contains the Prometheus executable, configuration file, `promtool`, console files, and console libraries. 

---

# Step 3: Understand the important files

Inside the directory:

```bash
ls -lh
```

Important files/directories include:

```text
prometheus
prometheus.yml
promtool
consoles/
console_libraries/
```

### `prometheus`

The actual Prometheus server executable.

### `prometheus.yml`

Main Prometheus configuration file.

It defines things such as:

```text
scrape targets
jobs
scrape intervals
rules
```

### `promtool`

Command-line utility used to validate and work with Prometheus configuration.

### `consoles/`

Console templates used for Prometheus's console functionality.

### `console_libraries/`

Libraries required by the console templates.

The transcript specifically identifies these files and their purposes. 

---

# Part 2 — Test Prometheus Manually

Before creating a systemd service, you can test the binary directly.

From the Prometheus directory:

```bash
./prometheus
```

If there are no configuration/startup errors, Prometheus should start. 

By default, Prometheus listens on:

```text
9090
```

Open:

```text
http://<PROMETHEUS-SERVER-IP>:9090
```

or locally:

```text
http://localhost:9090
```

The transcript identifies `9090` as the default Prometheus port. 

---

# Step 3 — Verify Prometheus

Open the Prometheus expression browser.

Run:

```promql
up
```

Click **Execute**.

You should see something like:

```text
up{instance="localhost:9090",job="prometheus"} 1
```

`1` means:

```text
UP
```

`0` means:

```text
DOWN
```

Prometheus is configured by default to scrape its own metrics, which is why you should see the Prometheus target even without configuring another application. 

---

# Part 3 — Why We Need systemd

Running:

```bash
./prometheus
```

is fine for testing, but **not ideal for production**.

The transcript identifies two problems:

### Problem 1 — Foreground process

If you close the terminal:

```text
Terminal closes
      ↓
Prometheus stops
```

### Problem 2 — Doesn't automatically start after reboot

After:

```bash
reboot
```

you would have to manually start Prometheus again.

So we configure:

```text
systemd
```

This allows:

```bash
systemctl start prometheus
systemctl stop prometheus
systemctl restart prometheus
systemctl status prometheus
```

and automatic startup after reboot. 

---

# Part 4 — Create a Prometheus User

Create a dedicated Linux user:

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
```

The purpose is to **avoid running Prometheus as root**.

The transcript creates a dedicated `prometheus` user specifically for running the Prometheus process. 

Check:

```bash
id prometheus
```

---

# Part 5 — Create Configuration Directory

Create:

```bash
sudo mkdir -p /etc/prometheus
```

This will contain:

```text
/etc/prometheus/prometheus.yml
```

The transcript uses `/etc/prometheus` for configuration because `/etc` is conventionally used for system configuration. 

---

# Part 6 — Create Prometheus Data Directory

Create:

```bash
sudo mkdir -p /var/lib/prometheus
```

This is where Prometheus's time-series data will be stored.

Conceptually:

```text
/etc/prometheus
        │
        └── prometheus.yml

/var/lib/prometheus
        │
        └── Prometheus TSDB data
```

The transcript explicitly separates configuration under `/etc/prometheus` from data under `/var/lib/prometheus`. 

---

# Part 7 — Set Ownership

Make the Prometheus user the owner:

```bash
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
```

This ensures Prometheus can:

* Read its configuration
* Write its database
* Manage its required files

The transcript emphasizes changing ownership of both directories to the `prometheus` user/group. 

---

# Part 8 — Install the Prometheus Binary

Copy the executable:

```bash
sudo cp prometheus /usr/local/bin/
```

Copy `promtool`:

```bash
sudo cp promtool /usr/local/bin/
```

Now verify:

```bash
which prometheus
which promtool
```

Expected:

```text
/usr/local/bin/prometheus
/usr/local/bin/promtool
```

The transcript places both executables in the local system binary directory. 

---

# Part 9 — Set Binary Ownership

```bash
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
```

The transcript also changes ownership of these binaries to the Prometheus user. 

---

# Part 10 — Copy Console Files

Copy:

```bash
sudo cp -r consoles /etc/prometheus/
```

and:

```bash
sudo cp -r console_libraries /etc/prometheus/
```

Then:

```bash
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
```

The `-R` option applies ownership recursively to the directories and their contents. 

---

# Part 11 — Copy Prometheus Configuration

Copy the configuration file:

```bash
sudo cp prometheus.yml /etc/prometheus/
```

Then:

```bash
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml
```

Now your configuration is:

```text
/etc/prometheus/prometheus.yml
```

The transcript specifically moves the configuration file into `/etc/prometheus`. 

---

# Part 12 — Validate Configuration

Before starting the service, use `promtool`.

```bash
promtool check config /etc/prometheus/prometheus.yml
```

You want a successful validation message.

This is an important operational step because `promtool` is included specifically as a utility for checking Prometheus configuration. 

---

# Part 13 — Test the Production-Style Start Command

The transcript starts Prometheus using the dedicated user and explicitly provides the configuration, storage, and console paths.

Conceptually:

```bash
sudo -u prometheus /usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
```

The important idea is:

```text
Prometheus user
      ↓
Prometheus binary
      ↓
Configuration
      ↓
TSDB storage
      ↓
Console templates/libraries
```

The transcript explicitly explains these flags and paths. 

---

# Part 14 — Create systemd Service

Create:

```bash
sudo vim /etc/systemd/system/prometheus.service
```

The service should conceptually contain:

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus

ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
```

### Important sections

#### `[Unit]`

```ini
After=network-online.target
```

Prometheus starts after the network is available.

This is important because Prometheus needs network connectivity to scrape targets. 

#### `[Service]`

```ini
User=prometheus
Group=prometheus
```

Prometheus runs as the dedicated non-root user.

```ini
ExecStart=...
```

Defines the command systemd executes.

#### `[Install]`

```ini
WantedBy=multi-user.target
```

Allows Prometheus to start as part of normal system startup. 

---

# Part 15 — Reload systemd

Whenever you create or modify a systemd unit:

```bash
sudo systemctl daemon-reload
```

This tells systemd:

> "Reload your unit files because something changed."

The transcript performs a daemon reload after creating the service file. 

---

# Part 16 — Start Prometheus

```bash
sudo systemctl start prometheus
```

Check:

```bash
sudo systemctl status prometheus
```

You want:

```text
Active: active (running)
```

The transcript uses `systemctl start` and `systemctl status` to verify that Prometheus is running. 

---

# Part 17 — Enable Prometheus at Boot

This is very important:

```bash
sudo systemctl enable prometheus
```

Now:

```text
Server reboot
      ↓
systemd
      ↓
Prometheus automatically starts
```

Verify:

```bash
sudo systemctl is-enabled prometheus
```

Expected:

```text
enabled
```

The transcript explicitly enables Prometheus so it starts automatically during system boot. 

---

# Part 18 — Final Verification

Check service:

```bash
sudo systemctl status prometheus
```

Check port:

```bash
ss -lntp | grep 9090
```

Open:

```text
http://<server-ip>:9090
```

Then run:

```promql
up
```

You should see:

```text
1
```

That confirms Prometheus is running and its self-monitoring target is up. The transcript concludes by verifying Prometheus through port `9090`. 

---

# Complete Flow to Remember

For an interview or real administration task, remember the process like this:

```text
1. Download Prometheus
        ↓
2. Extract tar.gz
        ↓
3. Understand prometheus / prometheus.yml / promtool
        ↓
4. Test ./prometheus
        ↓
5. Verify localhost:9090
        ↓
6. Create prometheus Linux user
        ↓
7. Create /etc/prometheus
        ↓
8. Create /var/lib/prometheus
        ↓
9. Set ownership
        ↓
10. Copy prometheus + promtool
        ↓
11. Copy consoles + console_libraries
        ↓
12. Copy prometheus.yml
        ↓
13. Validate with promtool
        ↓
14. Create prometheus.service
        ↓
15. systemctl daemon-reload
        ↓
16. systemctl start prometheus
        ↓
17. systemctl status prometheus
        ↓
18. systemctl enable prometheus
        ↓
19. Verify :9090
        ↓
20. Run PromQL: up
```

## Engineer-level mental model

```text
                    Linux Server
                         │
              ┌──────────┴──────────┐
              │                     │
       /etc/prometheus       /var/lib/prometheus
              │                     │
       prometheus.yml          TSDB data
              │                     │
              └──────────┬──────────┘
                         │
                  systemd service
                         │
                         ▼
                   Prometheus
                         │
              ┌──────────┴──────────┐
              │                     │
           :9090                 Scraping
              │                     │
           Web UI              Applications
              │                VMs / Exporters
              │                Kubernetes
              │
           PromQL
```

**The key production principle:** don't leave Prometheus running with `./prometheus` in a terminal. Run it as a dedicated `prometheus` user under **systemd**, store configuration under `/etc/prometheus`, store TSDB data under `/var/lib/prometheus`, validate the configuration with `promtool`, and enable the service at boot. 
