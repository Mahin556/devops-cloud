## KUBERNETES THE HARD WAY

> #### Inspiration | https://github.com/kelseyhightower/kubernetes-the-hard-way

---

#### Involves:

```text
* You'll interact with every component as you install it.
* Testing each component individually before moving to the next.
* Understanding the APIs and interfaces each component exposes.
* Seeing how components communicate with each other.
* Exploring the configuration options and their effects.
```

This guide is NOT for setting up production-ready clusters. In some instances, the examples deliberately use simplified or insecure configurations to make the learning experience more accessible and help you focus on understanding the core concepts.

For production deployments, always follow security best practices, use proper certificate management, implement network policies, and consider using established tools like kubeadm, kops, or managed Kubernetes services.

---

#### Systemd

Most of the time to run control plane components within Kubernetes itself.

In this guide, you will run them as systemd services.

If you're curious and want to learn more about systemd, you can check out this excellent tutorial: [systemd by example](https://systemd-by-example.com/)

---

#### Lab Environment

- 2 VMs: 1 control, 1 master
- OS: Ubuntu 24:04
- Vagrant

---

#### Versions

```text
containerd: 2.3.3
runc: v1.5.1
CNI plugins: v1.9.1
nerdctl: 2.3.5
etcd: v3.6.4
Kubernetes: v1.34.0
Network addon (flannel): v0.27.2
CNI plugin: v1.7.1-flannel2
CoreDNS: 1.12.2
```

These are the latest versions available at the time of writing, following the version compatibility matrices provided by the respective projects.

---

#### [Prerequisites](/KUBERNETES/kubernetes-the-hard-way/setup-1/prereq.md)

#### [Containerd](/KUBERNETES/kubernetes-the-hard-way/setup-1/containerd/containerd.md)

#### [Kubelet](/KUBERNETES/kubernetes-the-hard-way/setup-1/kubelet/kubelet.md)

#### [Etcd](/KUBERNETES/kubernetes-the-hard-way/setup-1/etcd/etcd.md)

#### [Kube-apiserver](/KUBERNETES/kubernetes-the-hard-way/setup-1/kube-apiserver/kubeapi-server.md)

#### [Kube-scheduler](/KUBERNETES/kubernetes-the-hard-way/setup-1/kube-scheduler/kube-scheduler.md)

#### [Kube-controllermanager](/KUBERNETES/kubernetes-the-hard-way/setup-1/kube-controller-manager/kube-controller-manager.md)

#### [Joining the worker nodes](/KUBERNETES/kubernetes-the-hard-way/setup-1/joining-nodes-to-the-cluster/joining-nodes-to-the-cluster.md)

#### [Networking](/KUBERNETES/kubernetes-the-hard-way/setup-1/networking/network.md)

#### [Kube-proxy](/KUBERNETES/kubernetes-the-hard-way/setup-1/kube-proxy/kube-proxy.md)

#### [Kube-coredns](/KUBERNETES/kubernetes-the-hard-way/setup-1/coredns/coredns.md)

#### [Refrences](/KUBERNETES/kubernetes-the-hard-way/setup-1/refs.md)