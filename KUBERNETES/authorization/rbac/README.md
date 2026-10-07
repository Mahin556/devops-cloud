### References:
- [Day 36: Deep Dive into Kubernetes RBAC Authorization](https://www.youtube.com/watch?v=bP9oqYF_xlE&ab_channel=CloudWithVarJosh)

---

## Namespaced vs Cluster-Scoped Resources and RBAC Verbs

**Kubernetes resources can be either namespaced or non-namespaced (cluster-wide).**
  * Namespaced resources exist within a specific namespace (e.g., Pods, Deployments).
  * Non-namespaced resources are cluster-scoped (e.g., Nodes, PersistentVolumes).
  * You can check resource names and whether they are namespaced by running:
    ```bash
    kubectl api-resources
    kubectl api-resources --namespaced=false
    kubectl api-resources --namespaced=true
    ```
    ```bash
    root@kind-control-plane:/# kubectl api-resources --namespaced=true
    NAME                        SHORTNAMES   APIVERSION                     NAMESPACED   KIND
    bindings                                 v1                             true         Binding
    configmaps                  cm           v1                             true         ConfigMap
    endpoints                   ep           v1                             true         Endpoints
    events                      ev           v1                             true         Event
    limitranges                 limits       v1                             true         LimitRange
    persistentvolumeclaims      pvc          v1                             true         PersistentVolumeClaim
    pods                        po           v1                             true         Pod
    podtemplates                             v1                             true         PodTemplate
    replicationcontrollers      rc           v1                             true         ReplicationController
    resourcequotas              quota        v1                             true         ResourceQuota
    secrets                                  v1                             true         Secret
    serviceaccounts             sa           v1                             true         ServiceAccount
    services                    svc          v1                             true         Service
    controllerrevisions                      apps/v1                        true         ControllerRevision
    daemonsets                  ds           apps/v1                        true         DaemonSet
    deployments                 deploy       apps/v1                        true         Deployment
    replicasets                 rs           apps/v1                        true         ReplicaSet
    statefulsets                sts          apps/v1                        true         StatefulSet
    localsubjectaccessreviews                authorization.k8s.io/v1        true         LocalSubjectAccessReview
    horizontalpodautoscalers    hpa          autoscaling/v2                 true         HorizontalPodAutoscaler
    cronjobs                    cj           batch/v1                       true         CronJob
    jobs                                     batch/v1                       true         Job
    leases                                   coordination.k8s.io/v1         true         Lease
    endpointslices                           discovery.k8s.io/v1            true         EndpointSlice
    events                      ev           events.k8s.io/v1               true         Event
    ingresses                   ing          networking.k8s.io/v1           true         Ingress
    networkpolicies             netpol       networking.k8s.io/v1           true         NetworkPolicy
    poddisruptionbudgets        pdb          policy/v1                      true         PodDisruptionBudget
    rolebindings                             rbac.authorization.k8s.io/v1   true         RoleBinding
    roles                                    rbac.authorization.k8s.io/v1   true         Role
    resourceclaims                           resource.k8s.io/v1             true         ResourceClaim
    resourceclaimtemplates                   resource.k8s.io/v1             true         ResourceClaimTemplate
    csistoragecapacities                     storage.k8s.io/v1              true         CSIStorageCapacity
      
    root@kind-control-plane:/# kubectl api-resources --namespaced=false
    NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND
    componentstatuses                   cs           v1                                false        ComponentStatus
    namespaces                          ns           v1                                false        Namespace
    nodes                               no           v1                                false        Node
    persistentvolumes                   pv           v1                                false        PersistentVolume
    mutatingwebhookconfigurations                    admissionregistration.k8s.io/v1   false        MutatingWebhookConfiguration
    validatingadmissionpolicies                      admissionregistration.k8s.io/v1   false        ValidatingAdmissionPolicy
    validatingadmissionpolicybindings                admissionregistration.k8s.io/v1   false        ValidatingAdmissionPolicyBinding
    validatingwebhookconfigurations                  admissionregistration.k8s.io/v1   false        ValidatingWebhookConfiguration
    customresourcedefinitions           crd,crds     apiextensions.k8s.io/v1           false        CustomResourceDefinition
    apiservices                                      apiregistration.k8s.io/v1         false        APIService
    selfsubjectreviews                               authentication.k8s.io/v1          false        SelfSubjectReview
    tokenreviews                                     authentication.k8s.io/v1          false        TokenReview
    selfsubjectaccessreviews                         authorization.k8s.io/v1           false        SelfSubjectAccessReview
    selfsubjectrulesreviews                          authorization.k8s.io/v1           false        SelfSubjectRulesReview
    subjectaccessreviews                             authorization.k8s.io/v1           false        SubjectAccessReview
    certificatesigningrequests          csr          certificates.k8s.io/v1            false        CertificateSigningRequest
    flowschemas                                      flowcontrol.apiserver.k8s.io/v1   false        FlowSchema
    prioritylevelconfigurations                      flowcontrol.apiserver.k8s.io/v1   false        PriorityLevelConfiguration
    ingressclasses                                   networking.k8s.io/v1              false        IngressClass
    ipaddresses                         ip           networking.k8s.io/v1              false        IPAddress
    servicecidrs                                     networking.k8s.io/v1              false        ServiceCIDR
    runtimeclasses                                   node.k8s.io/v1                    false        RuntimeClass
    clusterrolebindings                              rbac.authorization.k8s.io/v1      false        ClusterRoleBinding
    clusterroles                                     rbac.authorization.k8s.io/v1      false        ClusterRole
    deviceclasses                                    resource.k8s.io/v1                false        DeviceClass
    resourceslices                                   resource.k8s.io/v1                false        ResourceSlice
    priorityclasses                     pc           scheduling.k8s.io/v1              false        PriorityClass
    csidrivers                                       storage.k8s.io/v1                 false        CSIDriver
    csinodes                                         storage.k8s.io/v1                 false        CSINode
    storageclasses                      sc           storage.k8s.io/v1                 false        StorageClass
    volumeattachments                                storage.k8s.io/v1                 false        VolumeAttachment
    volumeattributesclasses             vac          storage.k8s.io/v1                 false        VolumeAttributesClass
    ```

**All Kubernetes resources have verbs (actions) associated with them.**
  * These verbs define what operations can be performed on the resources (e.g., create, delete, get).
  * When we create Roles or ClusterRoles, we use these verbs to specify permissions.
  * To see the available resources along with their verbs, use:
    ```bash
    kubectl api-resources -o wide
    ```
    ```bash
    root@kind-control-plane:/# kubectl api-resources -o wide
    NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND                               VERBS                                                        CATEGORIES
    bindings                                         v1                                true         Binding                            create
    componentstatuses                   cs           v1                                false        ComponentStatus                    get,list
    configmaps                          cm           v1                                true         ConfigMap                          create,delete,deletecollection,get,list,patch,update,watch   
    endpoints                           ep           v1                                true         Endpoints                          create,delete,deletecollection,get,list,patch,update,watch   
    events                              ev           v1                                true         Event                              create,delete,deletecollection,get,list,patch,update,watch   
    limitranges                         limits       v1                                true         LimitRange                         create,delete,deletecollection,get,list,patch,update,watch   
    namespaces                          ns           v1                                false        Namespace                          create,delete,get,list,patch,update,watch
    nodes                               no           v1                                false        Node                               create,delete,deletecollection,get,list,patch,update,watch   
    persistentvolumeclaims              pvc          v1                                true         PersistentVolumeClaim              create,delete,deletecollection,get,list,patch,update,watch   
    persistentvolumes                   pv           v1                                false        PersistentVolume                   create,delete,deletecollection,get,list,patch,update,watch   
    pods                                po           v1                                true         Pod                                create,delete,deletecollection,get,list,patch,update,watch   all
    podtemplates                                     v1                                true         PodTemplate                        create,delete,deletecollection,get,list,patch,update,watch   
    replicationcontrollers              rc           v1                                true         ReplicationController              create,delete,deletecollection,get,list,patch,update,watch   all
    resourcequotas                      quota        v1                                true         ResourceQuota                      create,delete,deletecollection,get,list,patch,update,watch   
    secrets                                          v1                                true         Secret                             create,delete,deletecollection,get,list,patch,update,watch       
    serviceaccounts                     sa           v1                                true         ServiceAccount                     create,delete,deletecollection,get,list,patch,update,watch   
    services                            svc          v1                                true         Service                            create,delete,deletecollection,get,list,patch,update,watch   all
            false        PriorityClass                      create,delete,deletecollection,get,list,patch,update,watch
    csidrivers                                       storage.k8s.io/v1                 false        CSIDriver                          create,delete,deletecollection,get,list,patch,update,watch
    csinodes                                         storage.k8s.io/v1                 false        CSINode                            create,delete,deletecollection,get,list,patch,update,watch
    csistoragecapacities                             storage.k8s.io/v1                 true         CSIStorageCapacity                 create,delete,deletecollection,get,list,patch,update,watch
    storageclasses                      sc           storage.k8s.io/v1                 false        StorageClass                       create,delete,deletecollection,get,list,patch,update,watch
    volumeattachments                                storage.k8s.io/v1                 false        VolumeAttachment                   create,delete,deletecollection,get,list,patch,update,watch
    volumeattributesclasses             vac          storage.k8s.io/v1                 false        VolumeAttributesClass              create,delete,deletecollection,get,list,patch,update,watch
    root@kind-control-plane:/# kubectl api-resources -o wide
    NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND                               VERBS                                                        CATEGORIES
    bindings                                         v1                                true         Binding                            create
    componentstatuses                   cs           v1                                false        ComponentStatus                    get,list
    configmaps                          cm           v1                                true         ConfigMap                          create,delete,deletecollection,get,list,patch,update,watch   
    endpoints                           ep           v1                                true         Endpoints                          create,delete,deletecollection,get,list,patch,update,watch   
    events                              ev           v1                                true         Event                              create,delete,deletecollection,get,list,patch,update,watch   
    limitranges                         limits       v1                                true         LimitRange                         create,delete,deletecollection,get,list,patch,update,watch   
    namespaces                          ns           v1                                false        Namespace                          create,delete,get,list,patch,update,watch
    nodes                               no           v1                                false        Node                               create,delete,deletecollection,get,list,patch,update,watch   
    persistentvolumeclaims              pvc          v1                                true         PersistentVolumeClaim              create,delete,deletecollection,get,list,patch,update,watch   
    persistentvolumes                   pv           v1                                false        PersistentVolume                   create,delete,deletecollection,get,list,patch,update,watch   
    pods                                po           v1                                true         Pod                                create,delete,deletecollection,get,list,patch,update,watch   all
    podtemplates                                     v1                                true         PodTemplate                        create,delete,deletecollection,get,list,patch,update,watch      
    replicationcontrollers              rc           v1                                true         ReplicationController              create,delete,deletecollection,get,list,patch,update,watch   all
    resourcequotas                      quota        v1                                true         ResourceQuota                      create,delete,deletecollection,get,list,patch,update,watch   
    secrets                                          v1                                true         Secret                             create,delete,deletecollection,get,list,patch,update,watch   
    serviceaccounts                     sa           v1                                true         ServiceAccount                     create,delete,deletecollection,get,list,patch,update,watch   
    services                            svc          v1                                true         Service                            create,delete,deletecollection,get,list,patch,update,watch   all
    mutatingwebhookconfigurations                    admissionregistration.k8s.io/v1   false        MutatingWebhookConfiguration       create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    validatingadmissionpolicies                      admissionregistration.k8s.io/v1   false        ValidatingAdmissionPolicy          create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    validatingadmissionpolicybindings                admissionregistration.k8s.io/v1   false        ValidatingAdmissionPolicyBinding   create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    validatingwebhookconfigurations                  admissionregistration.k8s.io/v1   false        ValidatingWebhookConfiguration     create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    customresourcedefinitions           crd,crds     apiextensions.k8s.io/v1           false        CustomResourceDefinition           create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    apiservices                                      apiregistration.k8s.io/v1         false        APIService                         create,delete,deletecollection,get,list,patch,update,watch   api-extensions
    controllerrevisions                              apps/v1                           true         ControllerRevision                 create,delete,deletecollection,get,list,patch,update,watch
    daemonsets                          ds           apps/v1                           true         DaemonSet                          create,delete,deletecollection,get,list,patch,update,watch   all
    deployments                         deploy       apps/v1                           true         Deployment                         create,delete,deletecollection,get,list,patch,update,watch   all
    replicasets                         rs           apps/v1                           true         ReplicaSet                         create,delete,deletecollection,get,list,patch,update,watch   all
    statefulsets                        sts          apps/v1                           true         StatefulSet                        create,delete,deletecollection,get,list,patch,update,watch   all
    selfsubjectreviews                               authentication.k8s.io/v1          false        SelfSubjectReview                  create
    tokenreviews                                     authentication.k8s.io/v1          false        TokenReview                        create
    localsubjectaccessreviews                        authorization.k8s.io/v1           true         LocalSubjectAccessReview           create
    selfsubjectaccessreviews                         authorization.k8s.io/v1           false        SelfSubjectAccessReview            create
    selfsubjectrulesreviews                          authorization.k8s.io/v1           false        SelfSubjectRulesReview             create
    subjectaccessreviews                             authorization.k8s.io/v1           false        SubjectAccessReview                create
    horizontalpodautoscalers            hpa          autoscaling/v2                    true         HorizontalPodAutoscaler            create,delete,deletecollection,get,list,patch,update,watch   all
    cronjobs                            cj           batch/v1                          true         CronJob                            create,delete,deletecollection,get,list,patch,update,watch   all
    jobs                                             batch/v1                          true         Job                                create,delete,deletecollection,get,list,patch,update,watch   all
    certificatesigningrequests          csr          certificates.k8s.io/v1            false        CertificateSigningRequest          create,delete,deletecollection,get,list,patch,update,watch      
    leases                                           coordination.k8s.io/v1            true         Lease                              create,delete,deletecollection,get,list,patch,update,watch      
    endpointslices                                   discovery.k8s.io/v1               true         EndpointSlice                      create,delete,deletecollection,get,list,patch,update,watch      
    events                              ev           events.k8s.io/v1                  true         Event                              create,delete,deletecollection,get,list,patch,update,watch      
    flowschemas                                      flowcontrol.apiserver.k8s.io/v1   false        FlowSchema                         create,delete,deletecollection,get,list,patch,update,watch      
    prioritylevelconfigurations                      flowcontrol.apiserver.k8s.io/v1   false        PriorityLevelConfiguration         create,delete,deletecollection,get,list,patch,update,watch      
    ingressclasses                                   networking.k8s.io/v1              false        IngressClass                       create,delete,deletecollection,get,list,patch,update,watch      
    ingresses                           ing          networking.k8s.io/v1              true         Ingress                            create,delete,deletecollection,get,list,patch,update,watch      
    ipaddresses                         ip           networking.k8s.io/v1              false        IPAddress                          create,delete,deletecollection,get,list,patch,update,watch      
    networkpolicies                     netpol       networking.k8s.io/v1              true         NetworkPolicy                      create,delete,deletecollection,get,list,patch,update,watch      
    servicecidrs                                     networking.k8s.io/v1              false        ServiceCIDR                        create,delete,deletecollection,get,list,patch,update,watch      
    runtimeclasses                                   node.k8s.io/v1                    false        RuntimeClass                       create,delete,deletecollection,get,list,patch,update,watch      
    poddisruptionbudgets                pdb          policy/v1                         true         PodDisruptionBudget                create,delete,deletecollection,get,list,patch,update,watch      
    clusterrolebindings                              rbac.authorization.k8s.io/v1      false        ClusterRoleBinding                 create,delete,deletecollection,get,list,patch,update,watch      
    clusterroles                                     rbac.authorization.k8s.io/v1      false        ClusterRole                        create,delete,deletecollection,get,list,patch,update,watch
    rolebindings                                     rbac.authorization.k8s.io/v1      true         RoleBinding                        create,delete,deletecollection,get,list,patch,update,watch
    roles                                            rbac.authorization.k8s.io/v1      true         Role                               create,delete,deletecollection,get,list,patch,update,watch
    deviceclasses                                    resource.k8s.io/v1                false        DeviceClass                        create,delete,deletecollection,get,list,patch,update,watch   
    resourceclaims                                   resource.k8s.io/v1                true         ResourceClaim                      create,delete,deletecollection,get,list,patch,update,watch
    resourceclaimtemplates                           resource.k8s.io/v1                true         ResourceClaimTemplate              create,delete,deletecollection,get,list,patch,update,watch
    resourceslices                                   resource.k8s.io/v1                false        ResourceSlice                      create,delete,deletecollection,get,list,patch,update,watch
    priorityclasses                     pc           scheduling.k8s.io/v1              false        PriorityClass                      create,delete,deletecollection,get,list,patch,update,watch
    csidrivers                                       storage.k8s.io/v1                 false        CSIDriver                          create,delete,deletecollection,get,list,patch,update,watch
    csinodes                                         storage.k8s.io/v1                 false        CSINode                            create,delete,deletecollection,get,list,patch,update,watch
    csistoragecapacities                             storage.k8s.io/v1                 true         CSIStorageCapacity                 create,delete,deletecollection,get,list,patch,update,watch
    storageclasses                      sc           storage.k8s.io/v1                 false        StorageClass                       create,delete,deletecollection,get,list,patch,update,watch
    volumeattachments                                storage.k8s.io/v1                 false        VolumeAttachment                   create,delete,deletecollection,get,list,patch,update,watch
    volumeattributesclasses             vac          storage.k8s.io/v1                 false        VolumeAttributesClass              create,delete,deletecollection,get,list,patch,update,watch
    ```

**Here is a quick reference table explaining the common verbs you will see in RBAC permissions:**

| Verb               | Description                                                                       |
| ------------------ | --------------------------------------------------------------------------------- |
| `create`           | Create a new resource (e.g., `kubectl create deployment nginx`)                   |
| `delete`           | Remove a specific resource (e.g., `kubectl delete pod nginx`)                     |
| `deletecollection` | Remove multiple resources at once (e.g., `kubectl delete pods --all`)             |
| `get`              | Retrieve details of a resource (e.g., `kubectl get pod nginx -o yaml`)            |
| `list`             | List resources of a certain type (e.g., `kubectl get pods`)                       |
| `patch`            | Modify part of an existing resource (e.g., `kubectl patch deployment nginx`)      |
| `update`           | Apply changes to an existing resource (e.g., `kubectl apply -f deployment.yaml`)  |
| `watch`            | Continuously observe changes in resources (e.g., `kubectl get pods --watch`)      |

---

## What is RBAC?

RBAC stands for **Role-Based Access Control**. It’s a method to regulate access based on a user's role within an organization.

In Kubernetes:

* **Roles**:
  * A Role defines a set of permissions (verbs like get, list, create, delete) on specific Kubernetes resources.
  * It is **namespaced**, meaning its permissions only apply inside one namespace.
* **RoleBindings**:
  * Connects a **Role** to a user, group, or service account (called a "subject").
  * Grants the Role’s permissions **only in that namespace**.
  * A RoleBinding can reference:
    * a Role (same namespace)
    * or a ClusterRole (permissions still limited to that namespace)
* **ClusterRoles**: 
  * Works like a Role but is **not namespaced**.
  * Used to grant access to:
    * cluster-wide resources (Nodes, PersistentVolumes)
    * or namespaced resources across *all* namespaces (e.g., all Pods in the cluster).
* **ClusterRoleBindings**: 
  * Connects a **ClusterRole** to a subject.
  * Grants permissions **cluster-wide** across all namespaces.
  * Cannot reference a Role (because Roles are namespaced).

> **Note:** A `RoleBinding` can reference a `ClusterRole`, allowing you to **reuse cluster-defined permissions** in a **specific namespace**. The `ClusterRole`'s rules will only apply **within the namespace** where the `RoleBinding` exists.

RBAC answers these questions:
* Who is the user? (like Seema)
* What resource do they want to access? (pods, deployments, secrets, etc.)
* Which operation do they want to perform? (get, list, create, delete, update)
* Where? (which namespace or cluster-wide)

---

> **Pro Tip:** Don’t just watch — **practice alongside me**. You’ll learn faster and retain more when you actively apply what we cover.

Follow the step-by-step instructions using the resources below:

* [Day 34 GitHub Notes](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025/tree/main/Day%2034)
* [Day 34 Video](https://www.youtube.com/watch?v=RZ9O5JJeq9k&ab_channel=CloudWithVarJosh)

Set up the user, generate the certs, configure `kubeconfig`, and you’ll be ready to test RBAC permissions like a real cluster admin.

---

### Setting Up the `dev` Namespace as Default

In the upcoming examples, we’ll be creating resources in the `dev` namespace. To keep our CLI commands clean and avoid repeatedly typing `-n dev` or `--namespace=dev`, we’ll set `dev` as the **default namespace** for our current context.

```bash
# Step 1: Create the dev namespace (if not already created)
kubectl create ns dev

# Step 2: Set dev as the default namespace for the current kubeconfig context
kubectl config set-context --current --namespace=dev
```

Now, any resource we create or modify will default to the `dev` namespace unless specified otherwise — making our workflow much smoother.

**Note:** You can follow the same process to create `prod` namespace which will be used in the last demo.

---

## Starting with Role and RoleBinding (Namespace-Scoped Permissions)

**Important Limitation: Roles Are Strictly Namespace-Scoped**

Unlike ClusterRoles, **Roles are strictly limited to namespace-scoped resources**.

Here’s why:

* A `Role` **must always be created within a specific namespace**.
* If you don’t explicitly set a namespace, it will default to the `"default"` namespace.
* Therefore, **Roles cannot be used to grant access to cluster-scoped resources** like Nodes, PersistentVolumes, or Namespaces themselves.

For example:

> You **cannot** create a `Role` that allows access to `nodes`, because `nodes` are cluster-scoped. Only a `ClusterRole` can define such permissions.

This limitation makes `Roles` suitable for fine-grained access control **within a single namespace**, but not for managing cluster-wide access.

---

Imagine Seema is a developer working in the `dev` namespace. She needs the ability to **create and list both Pods and Deployments**.

In Kubernetes, such permissions are granted using a **Role** and a **RoleBinding**.

---

### Step 1. Define a Role in the `dev` Namespace

Here’s a YAML manifest for a `Role` that gives access to both Pods and Deployments:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev         # This Role is scoped to the 'dev' namespace
  name: workload-editor  # Name of the Role
rules:
# Rule 1: Grant permissions on Pods (which belong to the core API group)
- apiGroups: [""]                         # "" = core API group
  resources: ["pods"]                     # Targeting 'pods' resource
  verbs: ["create", "list"]              # Allow 'create' and 'list' actions

# Rule 2: Grant permissions on Deployments (which belong to the 'apps' API group)
- apiGroups: ["apps"]                    # 'apps' API group contains Deployments, StatefulSets, etc.
  resources: ["deployments"]             # Targeting 'deployments' resource
  verbs: ["create", "list"]              # Allow 'create' and 'list' actions
```

**Key points:**

* You can define **multiple rules** inside a Role. Here, we have two: one for pods and one for deployments.
* `apiGroups: [""]` is for core API group (used for Pods), while `"apps"` is for Deployments.
* This Role is **scoped to the `dev` namespace** — it won’t apply to any other namespace.

---

### Step 2. Bind the Role to Seema (and a Group) using RoleBinding

Now, we need to associate the Role with Seema — and optionally, with a group she belongs to. Kubernetes RoleBindings support **multiple subjects**, including users, groups, and service accounts.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bind-workload-editor    # Name of the RoleBinding
  namespace: dev                # This RoleBinding is scoped to the 'dev' namespace
subjects:
  # Subject 1: Individual user 'seema'
  - kind: User
    name: seema
    apiGroup: rbac.authorization.k8s.io  # Required for User and Group kinds

  # Subject 2: Group of users (e.g., junior admins)
  - kind: Group
    name: junior-admins
    apiGroup: rbac.authorization.k8s.io  # Group permissions are managed the same way as User

roleRef:
  kind: Role                          # Referencing a Role (not ClusterRole)
  name: workload-editor               # Name of the Role being bound
  apiGroup: rbac.authorization.k8s.io  # Always this value for RBAC roles
```

**Highlights:**

* The `subjects` field is a list — so you can grant access to **multiple users or groups** in one go.
* You can associate the Role with:

  * `User` (like Seema)
  * `Group` (like `junior-admins`)
  * `ServiceAccount` (common for apps or controllers)
* `roleRef` points to the specific Role being granted (`workload-editor` in this case).

**Important Note on ServiceAccounts in RoleBindings**

When you bind a `ServiceAccount` as a subject in a RoleBinding or ClusterRoleBinding:

* The `apiGroup` **must be an empty string** (`""`)
* You **must also specify the namespace** where the ServiceAccount exists

**Example:**

```yaml
- kind: ServiceAccount
  name: my-service-account
  namespace: dev
  apiGroup: ""  # MUST be empty for ServiceAccounts
```

This distinction is crucial — using a non-empty `apiGroup` with a ServiceAccount will silently fail and result in no permissions being granted.

---

## What Happens When Seema Runs a Command?

When Seema executes:

```bash
kubectl create deployment nginx --image=nginx --namespace=dev
```

Here’s what Kubernetes does behind the scenes:

1. **Authentication**: The API server verifies that the user is Seema.
2. **Authorization**: The API server looks for:

   * RoleBindings in the `dev` namespace.
   * Finds `bind-workload-editor` that grants the `workload-editor` Role.
   * Confirms that Seema is listed in the `subjects`.
   * Checks the Role has permission to `create` deployments.
3. **Execution**: If all checks pass, the deployment is created.

---

### Key Pointers:

* **Roles** are used to define **namespaced permissions**, and can have **multiple rules**.
* **RoleBindings** assign those Roles to **users, groups, or service accounts**, and can list **multiple subjects**.
* Use **comments inside YAML** to make your manifests clearer — it helps with collaboration and reviews.
* We used Seema and a group (`junior-admins`) to show how real-world teams might be structured.

---

## ClusterRole and ClusterRoleBinding (Cluster-Scoped Permissions)

**Important Clarification: ClusterRoles Aren’t Just for Cluster-Scoped Resources**

It’s a common misconception that **ClusterRoles** and **ClusterRoleBindings** are only used for cluster-scoped resources like Nodes or PersistentVolumes.

**In reality**, you can use them to grant access **across all namespaces** for resources that are normally namespace-scoped.

For example:

> Deployments are namespace-scoped resources.
> But if you define a **ClusterRole** that allows actions on Deployments, and bind it using a **ClusterRoleBinding**, then the subject (user, group, or service account) will gain those permissions **in every namespace**.

This is useful when a platform admin or automation service needs consistent access across the entire cluster, without having to create duplicate Roles and RoleBindings in each namespace.

---

Let’s say Seema needs **read access to nodes**. Since nodes are **cluster-level resources**, a namespaced Role won't work. This is where ClusterRoles come in.

---

### Step 1: Define a ClusterRole (`node-reader`)
```yaml
apiVersion: rbac.authorization.k8s.io/v1          # API version for RBAC resources
kind: ClusterRole                                 # ClusterRole applies permissions across the whole cluster
metadata:
  name: node-reader                               # Name of the ClusterRole
rules:
- apiGroups: [""]                                  # "" indicates the core API group (e.g., nodes, pods)
  resources: ["nodes"]                             # Targeting the 'nodes' resource (which is cluster-scoped)
  verbs: ["get", "list", "watch"]                  # Allow read-only actions: get one node, list all, or watch for changes
```

---

### Step 2: Bind ClusterRole to Seema using ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1            # API version for RBAC resources
kind: ClusterRoleBinding                             # Grants cluster-wide access to the subject
metadata:
  name: bind-node-reader                             # Name of the ClusterRoleBinding
subjects:
- kind: User                                          # Type of subject: can be User, Group, or ServiceAccount
  name: seema                                         # Name of the user being granted access
  apiGroup: rbac.authorization.k8s.io                # Always this value for RBAC subjects
roleRef:
  kind: ClusterRole                                   # Binding to a ClusterRole (not Role)
  name: node-reader                                   # Name of the ClusterRole defined earlier
  apiGroup: rbac.authorization.k8s.io                # Always this value for RBAC role references
```

---

### Bonus Tip: What about ServiceAccounts?

If you’re binding a **ServiceAccount**, remember:

```yaml
- kind: ServiceAccount
  name: example-sa
  namespace: dev
  apiGroup: ""  # MUST be empty for ServiceAccount subjects
```

Setting `apiGroup` to anything other than `""` will silently break the binding.

---

## Verify Seema’s Effective Access

Use these commands to check if Seema has the expected permissions:

```bash
kubectl auth can-i create pods --namespace=dev --as=seema
kubectl auth can-i get nodes --as=seema
```

If `yes`, your RBAC setup is working perfectly.

---
## Extra Insight: ClusterRoles Can Be Used in Namespaces Too!


A **ClusterRole** is more versatile than many assume. Here are two key capabilities:

1. **Reusable Across Namespaces:**
   A **ClusterRole** can define permissions for **namespaced resources** (like Deployments or ConfigMaps), not just cluster-scoped ones. A common misconception is that ClusterRoles are only for cluster-wide resources — but that’s not true. You can reference a ClusterRole in a **RoleBinding** within a specific namespace to reuse the same permission set across multiple namespaces without redefining it.

2. **Cluster-Wide Access to Namespaced Resources:**
   When you bind a ClusterRole using a **ClusterRoleBinding**, you can grant access to namespaced resources (like Deployments) **across all namespaces**. This is a powerful pattern when you want a user, group, or service account to manage a particular type of resource cluster-wide, regardless of namespace.


---

### Step 1: Define a ClusterRole (`elevated-workload-editor`)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: elevated-workload-editor               # Name of the ClusterRole for elevated workload permissions
rules:
  # Rule 1: Manage Pods in the core API group
  - apiGroups: [""]                             # Core API group (no group name)
    resources: ["pods"]                        # Pod resource (namespace-scoped)
    verbs: ["create", "delete", "update"]     # Allowed actions on pods: create, delete, update

  # Rule 2: Manage Deployments in the 'apps' API group
  - apiGroups: ["apps"]                        # Named API group for apps resources
    resources: ["deployments"]                 # Deployment resource (namespace-scoped)
    verbs: ["create", "delete", "update", "patch"]  # Allowed actions on deployments
```

**Explanation:**

* This ClusterRole grants elevated permissions on **pods** and **deployments**, covering common workload management tasks.
* Since it’s a ClusterRole, it can be referenced by:

  * **RoleBindings** inside any namespace to apply these permissions namespace-wise.
  * **ClusterRoleBindings** to grant access cluster-wide (across all namespaces).

---

### Step 2: Bind ClusterRole to a user in a specific namespace (`prod`)

Here’s an enhanced version with detailed inline comments and clear explanation:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: use-clusterrole-in-prod
  namespace: prod                              # RoleBinding applies only within the 'prod' namespace
roleRef:
  kind: ClusterRole                            # Refers to a ClusterRole (not a Role)
  name: elevated-workload-editor               # The ClusterRole being referenced
  apiGroup: rbac.authorization.k8s.io         # Standard API group for RBAC
subjects:
  # Subject: User 'seema' granted permissions
  - kind: User
    name: seema
    apiGroup: rbac.authorization.k8s.io
```

**Explanation:**

* This RoleBinding is **namespace-scoped** (in `prod`), but it binds to a **ClusterRole** instead of a Role.
* This means Seema gets the permissions defined in `elevated-workload-editor` **only within the `prod` namespace**.
* You can reuse the same ClusterRole in multiple namespaces by creating RoleBindings in each namespace (`staging`, `dev`, `test`, etc.), avoiding permission duplication.
* Auto complication will also not work here.

---

## Quick Recap: RBAC Building Blocks

| Resource             | Scope        | Purpose                                         | Binds to                                      |
| -------------------- | ------------ | ----------------------------------------------- | --------------------------------------------- |
| `Role`               | Namespace    | Define permissions inside a namespace           | Used in a `RoleBinding`                       |
| `RoleBinding`        | Namespace    | Assign Role (or ClusterRole) to subject         | User / Group / ServiceAccount                 |
| `ClusterRole`        | Cluster-wide | Define permissions for all or across namespaces | Used in `RoleBinding` or `ClusterRoleBinding` |
| `ClusterRoleBinding` | Cluster-wide | Assign ClusterRole to subject globally          | User / Group / ServiceAccount                 |

---


## Real-World Advice & Best Practices

* Always follow the **principle of least privilege** — grant only what is absolutely needed.
* Use **Role + RoleBinding** for namespace-specific permissions.
* Use **ClusterRole + ClusterRoleBinding** sparingly — only for truly cluster-wide access.
* Prefer binding to **groups** or **service accounts** for scalable, manageable access control.
* When using service accounts, remember that their `apiGroup` must be `""` (empty).
* Reuse **ClusterRoles** with **RoleBindings** in namespaces to avoid duplication.
* Regularly **audit** and **review** your RBAC setup. Use `kubectl auth can-i` to validate access.

---

## Conclusion

RBAC is more than just a checkbox for compliance — it’s your frontline defense in Kubernetes security. Today, we didn’t just define Roles and Bindings, we explored how real permissions map to real users like Seema, across both namespace and cluster scopes.

Remember:

* Use **Role + RoleBinding** for scoped, precise control.
* Use **ClusterRole + ClusterRoleBinding** carefully — with least privilege in mind.
* Reuse **ClusterRoles** across namespaces with **RoleBindings** to stay DRY.
* Test everything with `kubectl auth can-i` before handing over access.

RBAC isn’t about memorizing YAML — it’s about understanding **intent** and **impact**. The more you practice, the more intuitive it gets. In the next session, we’ll build on this by exploring **Service Accounts** — the primary way workloads interact with the API server.

Keep your clusters secure, and your YAML clean.

---

## References

[Official Kubernetes RBAC Docs](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---