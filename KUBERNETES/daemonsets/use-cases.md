### Common Use Cases for DaemonSets

DaemonSets are used when you need a Pod to run on **every node** in the cluster, or on a specific group of nodes. They guarantee node-level coverage, something ReplicaSets cannot provide.
Basically when you want to install any node level component.

##### 1. Logging Agents (Node + Application Logs)
  Run log collectors on every node so all container and system logs are shipped to a central logging backend.
  Examples:
  - Fluentd / Fluent Bit
  - Logstash
  - Splunk Forwarder
  - Humio
  - Filebeat

##### 2. Monitoring Agents (Node-Level Metrics)
  Deploy node-level monitoring exporters to gather CPU, memory, disk, and network metrics from every node.
  Examples:
  - Prometheus Node Exporter
  - Datadog Agent
  - New Relic Infrastructure Agent

##### 3. Kubernetes System Components
  Some core Kubernetes components run as DaemonSets.
  Example:
  - kube-proxy (handles service → pod networking and traffic routing)

##### 4. Networking Plugins (CNI)
  Network plugins must run on every node to set up routing rules, iptables, firewall configuration, or overlay networks.
  Examples:
  - Calico
  - Flannel
  - Weave
  - Cilium

##### 5. Security & Compliance Agents
  Security tools that need node-level visibility run as DaemonSets.
  Examples:
  - Falco (runtime security)
  - kube-bench (CIS benchmark scans)
  - Intrusion detection systems
  - Vulnerability scanners for PCI/PII-compliant nodes

##### 6. Storage Plugins (CSI)
  Storage drivers often require node components to be present everywhere.
  Examples:
  - CSI Node Plugin
  - NFS/GFPP mount helpers
  - Local PV provisioners

##### 7. Specialized Hardware Nodes (GPU, FPGA)
  DaemonSets can install drivers or system services only on specific nodes that match labels.
  Examples:
  - NVIDIA GPU drivers daemonset
  - FPGA device plugins

##### 8. Telemetry and Observability Collectors
  Collectors that gather traces, events, and logs at the node level.
  - Examples:
    - OpenTelemetry Collector (DaemonSet mode)  


##### Why Use DaemonSets?
  - Ensures a Pod runs **on every node**
  - Automatically schedules Pods on **new nodes** as they join
  - Automatically removes Pods when nodes leave
  - Useful for system-level services that support the entire cluster
  - Guaranteed node coverage → **ReplicaSets cannot guarantee this**

DaemonSets are ideal when you need consistent, reliable node-level functionality across the entire Kubernetes cluster.
