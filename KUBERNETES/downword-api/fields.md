### Exposed fileds that can be access using Downdard API

✅ **Pod Fields** (`fieldRef`):

Available via both env & volume:
    * metadata.name → Pod name
    * metadata.namespace → Pod namespace
    * metadata.uid → Pod UID
    * metadata.annotations['KEY'] → single annotation value
    * metadata.labels['KEY'] → single label value

Env only (❌ not available in volume):
    * spec.serviceAccountName → Pod’s ServiceAccount
    * spec.nodeName → Node name where Pod is running
    * status.hostIP → Node IP
    * status.hostIPs → Node IPs (dual-stack)
    * status.podIP → Pod IP
    * status.podIPs → Pod IPs (dual-stack)

Volume only (❌ not available as env):
    * metadata.labels → all labels in file
    * metadata.annotations → all annotations in file

✅ **Container Fields** (`resourceFieldRef`):

Available via env & volume:
    * limits.cpu, requests.cpu
    * limits.memory, requests.memory
    * limits.hugepages-*, requests.hugepages-*
    * limits.ephemeral-storage, requests.ephemeral-storage
⚠️ Note: If CPU/memory limits aren’t set, kubelet exposes node allocatable values as fallback.
