## Containerd in Kubernetes

---

### Repositories 
> containerd | https://github.com/containerd/containerd

> runc | https://github.com/opencontainers/runc

> nerdctl | https://github.com/containerd/nerdctl

> cni | https://github.com/containernetworking/plugins/

---

## Objectives

Kubernetes needs a container runtime to actually run containers. In this lesson, you'll install containerd and learn how it orchestrates container execution through OCI runtimes and CNI plugins.

### Objectives

* Understand containerd's role within a Kubernetes cluster
* Install and configure containerd from scratch
* Explore the tools and ecosystem surrounding containerd
* Understand how containerd relies on open standards such as CNI (Container Network Interface) and OCI (Open Container Initiative) to perform container operations

By the end of this lesson, you'll have a fully configured container runtime capable of pulling images and running containers.

---

# What is containerd?

containerd is an industry-standard container runtime that provides the fundamental tools for running containers.

Originally developed by Docker, containerd is now maintained by the CNCF and has become one of the most widely adopted container runtimes in the [cloud-native](https://www.google.com/search?q=what+is+meaning+of+cloud+native&oq=what+is+meaning+of+cloud+native&gs_lcrp=EgZjaHJvbWUyCggAEEUYFhgeGDkyCAgBEAAYFhgeMggIAhAAGBYYHjIICAMQABgWGB4yCAgEEAAYFhgeMg0IBRAAGIYDGIAEGIoFMg0IBhAAGIYDGIAEGIoFMg0IBxAAGIYDGIAEGIoF0gEIODgzM2owajeoAgCwAgA&sourceid=chrome&source=chrome.ob&ie=UTF-8) ecosystem.

containerd provides several essential services to Kubernetes:

* Container Lifecycle Management: Creating, starting, stopping, and deleting containers
* Image Management: Pulling, storing, and managing container images from registries
* Storage Management: Handling container filesystems and volume mounts
* Network Management: Coordinating with CNI plugins for container networking
* Runtime Management: Interfacing with low-level runtimes

---

# Installing containerd

containerd can be downloaded from the project's GitHub Releases page.

Download and install containerd:

```bash
CONTAINERD_VERSION=2.3.3

curl -fsSLO "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION?}/containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"

sudo tar xzvofC "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz" /usr/local

sudo tar -tzf "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"
# bin/
# bin/containerd
# bin/containerd-shim-runc-v2
# bin/ctr
# bin/containerd-stress

sudo rm "containerd-${CONTAINERD_VERSION?}-linux-amd64.tar.gz"
```

Download the systemd unit file to run containerd as a systemd service:

```bash
sudo wget -P /etc/systemd/system/ "https://raw.githubusercontent.com/containerd/containerd/v${CONTAINERD_VERSION?}/containerd.service"
```
```bash
cat /etc/systemd/system/containerd.service
```
```bash
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target dbus.service

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
```

Start the containerd service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
systemctl status containerd.service --no-pager
```

> **Note**
>
> 💡 If you encounter any issues, check out the Tips & Tricks at the beginning of the course.

---

# Using ctr

containerd includes a CLI tool called **ctr** for basic container operations.

> **Note**
>
> 💡 Think of ctr as similar to the Docker CLI, but designed for lower-level container operations.

Unlike higher-level tools like the Docker CLI, ctr requires you to manually pull an image before running it:

```bash
sudo ctr images pull ghcr.io/sagikazarmark/docker-hello-world:latest
```

With the image pulled, you can run the container:

```bash
sudo ctr run --rm ghcr.io/sagikazarmark/docker-hello-world:latest hello
```

> **Important**
>
> ⚠️ This command will fail because no OCI runtime is installed yet. The error output shows what's missing.

```text
ctr: failed to create shim task: OCI runtime create failed:
unable to retrieve OCI runtime error
(open /run/containerd/io.containerd.runtime.v2.task/default/hello/log.json: no such file or directory):
exec: "runc": executable file not found in $PATH
```

The next section covers OCI runtimes and how to install them to resolve this issue.

---

# OCI Runtime

containerd is a high-level container runtime that provides a wide range of container management services (like image management, storage, and networking), but delegates certain tasks to specialized components. One such task is actually running the container process, which containerd delegates to a low-level OCI runtime.

In practical terms, containerd manages the "what" (which container to run, with what image, network, and storage), while OCI runtimes handle the "how" (the underlying isolation mechanisms like cgroups, namespaces, or VMs).

Historically, container management used a highly integrated, monolithic architecture (think Docker Engine).

As the ecosystem matured and standardization efforts advanced, the need for a more modular and flexible approach became clear.

This evolution led to the development of various high-level container runtimes and the establishment of the Open Container Initiative (OCI).

The OCI Runtime Specification standardizes how containers should be created, started, and managed at the low level, abstracting away platform-specific isolation details. This allows high-level runtimes like containerd to work with any OCI-compliant (aka. low-level) runtime without knowing the implementation details.

The containerd-shim is a lightweight process that acts as a bridge between containerd and OCI runtimes.

It provides a stable interface for containerd to interact with the runtime, keeps containers running even if containerd crashes, handles container I/O, and reaps processes when they exit.

The reference OCI runtime implementation is **runc**, which serves as the default runtime for containerd.

> **Note**
>
> 💡 Other OCI runtimes provide different isolation mechanisms: crun (also uses cgroups/namespaces but with better performance) and gVisor (uses a user-space kernel for VM-like isolation).

Although runc remains the most widely used and well-tested option, the beauty of OCI is that containerd can use any of these runtimes interchangeably without code changes.

---

# Installing runc

Download and install runc:

```bash
RUNC_VERSION=v1.5.1

curl -fsSLO "https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION?}/runc.amd64"

sudo install -m 755 runc.amd64 /usr/local/sbin/runc
```

Configure containerd to use the systemd cgroup driver with runc.

`/etc/containerd/config.toml`

```toml
version = 3

[plugins."io.containerd.cri.v1.runtime".containerd.runtimes.runc.options]
SystemdCgroup = true
```

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
cat /etc/containerd/config.toml | grep -i SystemdCgroup
```

> **Note**
>
> 💡 cgroups (control groups) limit and isolate resource usage (CPU, memory, I/O) for container processes.
>
> When using systemd as the init system, it's recommended to use the systemd cgroup driver so both systemd and the container runtime manage cgroups consistently.
>
> This ensures the container runtime and systemd coordinate through a single cgroup hierarchy, rather than managing resources separately, which can cause instability under memory or CPU pressure.

Restart the containerd service to apply the configuration changes:

```bash
sudo systemctl restart containerd
sudo systemctl status containerd --no-pager
```

With runc installed and configured, the container now runs successfully:

```bash
sudo ctr run --rm ghcr.io/sagikazarmark/docker-hello-world:latest hello
```

---

# nerdctl

While ctr is an excellent tool for low-level interaction with containerd, it isn't the most user-friendly tool, especially for users familiar with the Docker CLI.

Fortunately, there's an alternative tool called **nerdctl (contaiNERD CTL)** that provides a Docker CLI-like interface for interacting with containerd.

Download and install nerdctl:

```bash
NERDCTL_VERSION=2.3.5

curl -fsSLO "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION?}/nerdctl-${NERDCTL_VERSION?}-linux-amd64.tar.gz"

tar xzvof "nerdctl-${NERDCTL_VERSION?}-linux-amd64.tar.gz"

sudo install -m 755 nerdctl /usr/local/bin

nerdctl completion bash | sudo tee /etc/bash_completion.d/nerdctl
```

Unlike ctr, nerdctl automatically handles image pulling and network setup.

Verify this by running a container:

```bash
sudo nerdctl run --rm ghcr.io/stefanprodan/podinfo:latest /home/app/podinfo --version
```

> **Important**
>
> ⚠️ This command will fail because CNI plugins are not installed yet.

```text
FATA[0000] failed to create shim task: OCI runtime create failed:
runc create failed: unable to start container process:
error during container init: error running createRuntime hook #0:
exit status 1, stdout: , stderr: time="2025-07-17T12:39:15Z" level=warning msg="Container failed starting. Removing allocated network configuration."

time="2025-07-17T12:39:15Z" level=fatal msg="failed to call cni.Setup: plugin type=\"bridge\" failed (add): failed to find plugin \"bridge\" in path [/opt/cni/bin]"
```

While ctr doesn't automatically create a network for containers, nerdctl attempts to create a bridge network by default. Without CNI plugins installed, this network creation fails.

Work around this by telling nerdctl to use the host network instead:

```bash
sudo nerdctl run --net host --rm ghcr.io/stefanprodan/podinfo:latest /home/app/podinfo --version
```

> **Important**
>
> ⚠️ This is only a workaround for educational purposes.
>
> In a production environment, you should install CNI plugins to manage network configurations.

The next section covers installing CNI plugins to resolve this issue.

---

# Container Network Interface (CNI)

Just as containerd delegates container process execution to OCI runtimes, it delegates network configuration to specialized components through the Container Network Interface (CNI).

CNI is a specification and set of libraries for configuring network interfaces in Linux containers. It provides a standardized way for container runtimes to set up container networking, including creating network namespaces, configuring IP addresses, and establishing connectivity between containers and the host system.

Various CNI plugins are available, many of which can be found in the official CNI plugins repository.

> **Note**
>
> 🔜 CNI usage in Kubernetes will be covered in a later lesson.

For now, understand that when you run a container with nerdctl, containerd uses the bridge CNI plugin by default to set up the container's network namespace.

---

# Installing CNI Plugins

Download and install CNI plugins:

```bash
CNI_PLUGINS_VERSION=v1.9.1

curl -fsSLO "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION?}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION?}.tgz"

sudo mkdir -p /opt/cni/bin

sudo tar xzvofC "cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION?}.tgz" /opt/cni/bin
```

> **Note**
>
> 💡 CNI plugins are installed in `/opt/cni/bin` by convention.
>
> Container runtimes and Kubernetes network add-ons look for them in this directory by default.

With CNI plugins installed, containerd is now fully functional.

Run the container again using nerdctl:

```bash
sudo nerdctl run -d --name podinfo ghcr.io/stefanprodan/podinfo:latest
```

Verify that the container is running:

```bash
sudo nerdctl ps
```

Verify that podinfo is working correctly:

```bash
PODINFO_IP=$(sudo nerdctl inspect --format '{{ .NetworkSettings.IPAddress }}' podinfo)
echo $PODINFO_IP
curl -f "http://${PODINFO_IP}:9898"
```

### Commands

```bash
ctr images pull docker.io/library/python:3

ctr images ls

ctr run -d docker.io/library/python:3 python
```
```bash
root@worker1:~# sudo nerdctl inspect podinfo | grep -i IPAddress
            "IPAddress": "10.4.0.2",
                    "IPAddress": "10.4.0.2",

                    
root@worker1:~# sudo nerdctl inspect python | grep -i IPAddress
            "IPAddress": "",
```

---

# Summary

In this lesson, you learned about containerd, the high-level container runtime that serves as the foundation for container management on Kubernetes worker nodes.

### Key takeaways

* Industry standard: containerd is a CNCF-maintained, industry-standard container runtime that originated from Docker and powers container execution in Kubernetes clusters
* Modular architecture: containerd orchestrates container operations while delegating specific tasks to specialized components: OCI runtimes (like runc) handle process execution and CNI plugins manage networking
* Essential services: Provides container lifecycle management, image management, storage coordination, and network interface setup for Pods
* Management tools: Use ctr for low-level debugging and nerdctl for Docker-like commands when working directly with containerd

With containerd now running and fully configured with runc and CNI plugins, you're ready to set up kubelet, the Kubernetes node agent that will use containerd to manage Pods.

> **Important**
>
> Although the lesson covered important concepts necessary to understand containerd's role in Kubernetes, there is so much more to learn about containerd and container technologies in general.
>
> Make sure to explore the referenced materials to get a deeper understanding of how containers work.

---

# Additional Resources

💡 To learn more about the concepts covered in this lesson, check out the resources below.

## 🧪 Playgrounds

* contaiNERD CTL

## 📖 Tutorials

* How Container Networking Works
* Controlling Process Resources with Linux Control Groups

## 📚 Courses

* How (and Why) to Use containerd from the Command Line

## 🛠️ Skills Paths

* Master Container Networking

> **Note**
>
> 💡 Check out Ivan's blog for extensive examples and explanations of containerization concepts.
>
> The Implementing Container Manager series is particularly useful to get a hands-on experience with container management.

💡 To learn more about the concepts covered in this lesson, check out the resources below.

* containerd
* Getting started
* nerdctl
* Open Container Initiative (OCI)
* runc
* Container Network Interface (CNI)
* Plugins
