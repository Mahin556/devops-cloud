## Demo 2: Helm Upgrade and Rollback in Action

### Our Task

In this demo, we’ll simulate a common real-world scenario:

* You deployed an app (`nginx:1.22`) using Helm
* Now you want to **upgrade** it to a newer version (`nginx:1.23`)
* After the upgrade, an issue is reported — so you **roll back** to the previous known-good version

We’ll explore:

* Helm upgrade and rollback mechanics
* Chart and app versioning best practices
* How Helm tracks release revisions
* What Helm does behind the scenes during rollbacks

---

### Step 1: Verify Current Release and Revision

Let’s confirm that `app1` is already installed from **Demo 1**.

```bash
helm list
```

Output:

```
NAME    NAMESPACE   REVISION  UPDATED                  STATUS    CHART        APP VERSION
app1    default     1         2025-07-09 11:00:00 IST  deployed  app1-chart-0.1.0   1.22
```

Check the **revision history**:

```bash
helm history app1
```

You should see only one revision:

```
REVISION  UPDATED                  STATUS     CHART               APP VERSION
1         2025-07-09 11:00:00 IST  deployed   app1-chart-0.1.0    1.22
```

---

### Step 2: Upgrade the Chart and Image Version

To upgrade the application, we will do two things:

1. **Update the `Chart.yaml`** to reflect new chart and app version
2. **Update the `values.yaml`** to change the Docker image tag

#### 2.1 Modify `Chart.yaml`

```yaml
version: 0.1.1
appVersion: "1.23"
```

#### 2.2 Modify `values.yaml`

```yaml
image:
  repository: nginx
  tag: "1.23"
```

This sets us up for an upgrade from `nginx:1.22` → `nginx:1.23`.

---

### Step 3: Perform Helm Upgrade

Now let’s apply the upgrade:

```bash
helm upgrade app1 ./app1-chart
```

If successful, Helm will update the release and assign a **new revision number**.

---

### Step 4: Post-Upgrade Validation

#### 4.1 Verify the upgrade status:

```bash
helm list
```

Expected output:

```
NAME    NAMESPACE   REVISION  UPDATED                  STATUS    CHART             APP VERSION
app1    default     2         2025-07-09 11:10:00 IST  deployed  app1-chart-0.1.1   1.23
```

#### 4.2 Review release revision history:

```bash
helm history app1
```

Expected output:

```
REVISION  UPDATED                  STATUS     CHART               APP VERSION
1         2025-07-09 11:00:00 IST  superseded app1-chart-0.1.0    1.22
2         2025-07-09 11:10:00 IST  deployed   app1-chart-0.1.1    1.23
```

#### 4.3 Verify running pods and image version:

```bash
kubectl get deploy -o wide
```

You should see pods running with the image `nginx:1.23`.

---

### Step 5: Rollback to Previous Version

Let’s assume something broke after the upgrade, and your app team asks you to revert.

Roll back to **Revision 1**:

```bash
helm rollback app1 1
```

Helm will now revert the release to what was deployed in the first revision (Chart v0.1.0, nginx:1.22).

---

### Step 6: Post-Rollback Verification

#### 6.1 Confirm revision history again:

```bash
helm history app1
```

Expected output:

```
REVISION  UPDATED                  STATUS     CHART               APP VERSION
1         2025-07-09 11:00:00 IST  superseded app1-chart-0.1.0    1.22
2         2025-07-09 11:10:00 IST  superseded app1-chart-0.1.1    1.23
3         2025-07-09 11:15:00 IST  deployed   app1-chart-0.1.0    1.22
```

> **Note:** Even rollback creates a new revision (Revision 3), so Helm maintains a complete timeline of changes.

#### 6.2 Confirm image version is back to nginx:1.22:

```bash
kubectl describe deployment app1-nginx | grep Image
```

Expected output:

```
Image:  nginx:1.22
```

You can also inspect running pods to confirm the image:

```bash
kubectl get pods -l app=app1-pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

---

### Bonus: Try Helm Upgrade with `--reuse-values`

If you only want to upgrade the chart (not the values) and keep all previously passed values:

```bash
helm upgrade app1 ./app1-chart --reuse-values
```

This is useful when you're only bumping chart logic or template logic, but don’t want to redefine your image tag, replicaCount, etc.

---

### Key Commands

| Command                 | Purpose                             |
| ----------------------- | ----------------------------------- |
| `helm upgrade`          | Upgrade a chart                     |
| `helm rollback`         | Revert to a previous revision       |
| `helm history`          | View all revisions of a release     |
| `helm list`             | List current releases and versions  |
| `helm status <release>` | Check details of a specific release |