The `spec.os.name` field tells Kubernetes **which operating system the Pod is intended to run on**.

```yaml
spec:
  os:
    name: windows
```

or:

```yaml
spec:
  os:
    name: linux
```

### Why use it?

It helps Kubernetes ensure the Pod is scheduled onto a **compatible node**.

For example:

```text
Cluster
├── Linux node
│    └── Linux Pods
│
└── Windows node
     └── Windows Pods
```

If you specify:

```yaml
os:
  name: windows
```

Kubernetes knows the Pod requires **Windows**.

If:

```yaml
os:
  name: linux
```

it requires **Linux**.

### Important

It does **not install Windows/Linux** inside the Pod. The **node itself must already have that OS**.

For most normal Kubernetes workloads, you don't need to specify it because `linux` is the default/typical environment.
