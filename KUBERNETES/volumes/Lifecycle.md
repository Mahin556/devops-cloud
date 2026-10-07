### References:-
- https://spacelift.io/blog/kubernetes-persistent-volumes

---

# **Lifecycle of PersistentVolumes (PVs) and PersistentVolumeClaims (PVCs)**

PVs and PVCs have their own independent lifecycles.
These lifecycles determine how storage is created, claimed, used, and eventually released.

Kubernetes defines **four main stages**:

---

## **1. Provisioning**

Provisioning is the process of **creating the PersistentVolume** and allocating storage using a storage backend or driver.

There are two provisioning methods:

### **Manual Provisioning**

* Admin creates a **PersistentVolume (PV)** object
* PV is available but not yet used

### **Dynamic Provisioning**

* A **PVC is created that requests storage**
* Kubernetes automatically provisions a matching PV via a StorageClass

At the end of this stage, the PV exists but is **not yet bound** to any claim.

---

## **2. Binding**

Binding occurs when a **PVC claims a PV**.

* Kubernetes continuously watches for PVCs and matches them to compatible PVs
* Matching is based on:

  * Access modes
  * Storage size
  * StorageClass
  * Volume modes

**Important:**

* **One PV can bind to only one PVC**
* If dynamic provisioning is used, the binding happens immediately after the PVC is created

After this stage, the PV enters the **Bound** state but may not yet be mounted to a Pod.

---

## **3. Using**

A PV enters the **Using** stage when:

* A Pod mounts the PVC
* Kubernetes attaches and mounts the correct volume inside the Pod’s filesystem

In this state:

* The PV is actively providing storage
* Applications are reading/writing data from the underlying storage backend

This is the **active** phase of the PV lifecycle.

---

## **4. Reclaiming**

When the PVC is deleted, the PV is released and enters the **Reclaiming** stage.

Kubernetes then follows the **Reclaim Policy** defined for the PV:

### **Reclaim Policies**

| Policy      | Meaning                                                       |
| ----------- | ------------------------------------------------------------- |
| **Delete**  | Underlying storage is deleted (e.g., cloud disk removed)      |
| **Recycle** | Volume is wiped and made available again (deprecated)         |
| **Retain**  | Storage persists; admin must manually handle cleanup or reuse |

After reclaiming, the PV may:

* Stay in **Released** (Retain)
* Be fully deleted (Delete)
* Be reset and reused (Recycle — deprecated)
