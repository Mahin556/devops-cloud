Unlike emptyDir(backed by node disk), ephemeral volumes are provisioned as PersistentVolumeClaims and support storage requests and access modes.

Generic ephemeral storage: a volume that is dynamically provisioned as a PersistentVolumeClaim but still tied to the Pod lifecycle. When the Pod is deleted, the PVC and its data are automatically cleaned up.