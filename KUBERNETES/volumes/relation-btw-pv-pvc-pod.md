# ✅ **Relationship Between PV, PVC, and Pod**

## **1️⃣ PV ↔ PVC = One-to-One Relationship**

A **PersistentVolume (PV)** can be bound to **only one** PersistentVolumeClaim (PVC) at a time.

* **One PV** → **One PVC**
* A PV **cannot** be claimed by multiple PVCs
* Once a PVC binds to a PV, no other PVC can take it until it is released

This is a strict **1:1 relationship**.

---

## **2️⃣ PVC ↔ Pod = Not Always One-to-One**

Between **PVC and Pod**, the relationship is *not strictly one-to-one*.

The reason:

### ✔ A PVC can be used by **multiple Pods** IF access mode allows it

Example: `ReadWriteMany (RWX)`

* Many Pods can mount the same PVC at the same time
* Example: NFS, EFS, CephFS

### ✔ A PVC used by RWOP or RWO will be mounted to only one Pod or Node

* `ReadWriteOncePod (RWOP)` → exactly 1 Pod
* `ReadWriteOnce (RWO)` → multiple Pods **only if running on same Node**

So PVC ↔ Pod **depends on the access mode**.

---

## 🔎 **Summary**

| Relationship  | Type             | Explanation                             |
| ------------- | ---------------- | --------------------------------------- |
| **PV ↔ PVC**  | **Always 1:1**   | One PV binds to one PVC only            |
| **PVC ↔ Pod** | **Many options** | Depends on access mode (RWO, RWX, etc.) |

---

## 📌 **Examples**

### **Case 1: PVC with RWX (shared storage)**

```
PVC1 ---> PodA
       ---> PodB
       ---> PodC
```

One PVC used by **many Pods**.

---

### **Case 2: PVC with RWO (Node-only write)**

```
PVC2 ---> PodA (Node1)
```

If PodB is scheduled on Node2 → cannot mount
If PodB is on Node1 → can mount (same Node)

---

### **Case 3: PV ↔ PVC**

```
PV1 <--> PVC1
```

No other PVC can claim PV1.
