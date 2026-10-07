**Kubernetes auditing records what happens through the Kubernetes API server.**

Whenever a request is sent to the Kubernetes API server, Kubernetes can generate an **audit event** describing that request.

For example:

```text
kubectl create deployment nginx
            |
            v
      kube-apiserver
            |
            v
       Audit Event
            |
            v
       Audit Log
```

We can get the info about:

* **Who** made the change?
* **What** resource was changed?
* **What operation** was performed?
* **When** did it happen?
* **Where** did the request originate?
* What was requested/returned, depending on the audit level?

---

### Why Do We Need Auditing?

Imagine someone deletes a Deployment:

```bash
kubectl delete deployment nginx
```

Later, you discover:

```text
Deployment nginx → gone
```

Pod logs won't necessarily tell you:

```text
WHO deleted it?
WHEN was it deleted?
FROM WHERE?
WHAT API request caused it?
```

Auditing provides this information.

Think:

```text
Normal logs
   ↓
What happened inside components?

Audit logs
   ↓
What API requests happened?
Who made them?
When?
Against which resource?
```

---

Audit logging happen at kube-apiserver level.

The basic flow is:

```text
User / kubectl
      |
      | API request
      v
kube-apiserver
      |
      +----> Audit event
      |
      v
Audit backend
      |
      +----> File
      |
      +----> External HTTP endpoint
```

---

### Audit Policy

The **Audit Policy** determines **What should be audited and at what level?**

The policy is normally defined in a YAML file such as:

```text
/etc/kubernetes/audit/policy.yaml
```

Conceptually:

```text
Audit Policy
     |
     +── Which resources?
     |
     +── Which audit level?
     |
     +── Which stages to omit?
```

The transcript identifies three important parts of an audit rule:

1. **Level**
2. **Stages**
3. **Resources** 

---

### Audit Stages

There are **four important audit stages**.
```text
RequestReceived
ResponseStarted
ResponseComplete
Panic
```

<br>

##### RequestReceived

This happens when the API server receives the request.

```text
Client
  |
  | Request
  v
API Server
  |
  +--> RequestReceived
```

Example:

```bash
kubectl get pods
```

The API server receives that request.

`RequestReceived` is the earliest stage.

Recording every request at this stage can generate a lot of unnecessary noise. 

<br>

##### ResponseStarted

This stage indicates that the API server has started sending a response.

It is particularly relevant to **long-running requests**, such as:

```text
watch
```

The transcript specifically highlights `watch` as an example. 

Think:

```text
Request
   ↓
API Server
   ↓
ResponseStarted
   ↓
... response continues ...
```

<br>

##### ResponseComplete

This means the response has completed.

Conceptually:

```text
Request
   ↓
Processing
   ↓
ResponseStarted
   ↓
ResponseComplete
```

Point where there are no more bytes to send and the response body is complete. 

---

##### Panic

The `Panic` stage represents an error/panic condition generated while handling the request.


---

### Audit Levels

There are four levels:

```text
None
Metadata
Request
RequestResponse
```

Each level determines **how much information is recorded**. 

##### Level: None

```yaml
level: None
```

> Don't log events matching this rule.

```text
None
 ↓
No audit information
```

##### Level: Metadata

```yaml
level: Metadata
```

This records information **about the request**, but not the request/response body.

Typical metadata includes:
```text
User
Timestamp
Resource
Verb
Source IP
```

For example:
```text
User: kubernetes-admin
Verb: create
Resource: deployments
Source IP: ...
```
But the actual request/response body isn't recorded at this level.

##### Level: Request

```yaml
level: Request
```

This includes:
```text
Metadata
+
Request body
```

But:
```text
Response body
```

is not logged.

So:

```text
Request
 ├── Metadata       ✅
 ├── Request body   ✅
 └── Response body  ❌
```

##### Level: RequestResponse

```yaml
level: RequestResponse
```

This records:

```text
Metadata
+
Request body
+
Response body
```

Therefore:

```text
RequestResponse
 ├── Metadata       ✅
 ├── Request body   ✅
 └── Response body  ✅
```

This generates substantially more log data.

---

### Why Not Use RequestResponse Everywhere?

Because audit logs can become **very large**.

For example:

```text
Metadata
   ↓
small amount of information

Request
   ↓
more information

RequestResponse
   ↓
much more information
```

---

### Audit Policy Structure

A simplified audit policy looks like:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy

rules:
- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets
```

This means:

```text
For Secrets
     ↓
Audit at Metadata level
```

---

### Example Scenario

The scenario is:

> Audit Secrets at **Metadata** level and Deployments at **RequestResponse** level.

Conceptually:

```text
Secrets
   ↓
Metadata

Deployments
   ↓
RequestResponse
```

A corresponding policy is approximately:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy

rules:
- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets

- level: RequestResponse
  resources:
  - group: "apps"
    resources:
    - deployments
```

---

### Omitting Audit Stages

You don't necessarily need to record every stage.

For example:

```yaml
omitStages:
- RequestReceived
```

Why?

Because `RequestReceived` can create a lot of noise.

So a rule might look like:

```yaml
- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets
  omitStages:
  - RequestReceived
```

---

### Audit Backends

Once you define what should be audited, you need somewhere to send/store the events.

Two main audit backends:

```text
1. Log backend
2. Webhook backend
```

<br>

##### Log Backend

The **log backend** writes audit events to a file.

Conceptually:

```text
API Server
    |
    v
Audit Event
    |
    v
Log Backend
    |
    v
audit.log
```

For example:

```text
/etc/kubernetes/audit/logs/audit.log
```

for the example configuration. 

##### Webhook Backend

The **webhook backend** sends audit events to an external HTTP API.

```text
API Server
     |
     v
Audit Event
     |
     v
Webhook
     |
     v
External HTTP API
```

This allows audit events to be sent to an external auditing/logging system. 

---

##### Important kube-apiserver Flags

This is one of the most important sections for the CKS exam.

```text
--audit-policy-file
--audit-log-path
--audit-log-max-age
--audit-log-max-backups
--audit-log-max-size
```

##### `--audit-policy-file`

Specifies the location of the audit policy.
```yaml
--audit-policy-file=/etc/kubernetes/audit/policy.yaml
```

Meaning:

```text
kube-apiserver
      |
      └── read policy from
             |
             └── /etc/kubernetes/audit/policy.yaml
```

##### `--audit-log-path`

Specifies where audit logs should be written.

Example:

```yaml
--audit-log-path=/etc/kubernetes/audit/logs/audit.log
```

Meaning:

```text
Audit events
     ↓
audit.log
```

##### `--audit-log-max-age`

Controls how many days old audit logs can be retained.

Example:

```yaml
--audit-log-max-age=30
```

Conceptually:

```text
Keep logs for up to 30 days
```

##### `--audit-log-max-backups`

Controls the maximum number of rotated audit log files retained.

Example:

```yaml
--audit-log-max-backups=2
```

Think:

```text
audit.log
audit.log.1
audit.log.2
```

The exact rotation behavior depends on the configured values, but the important exam concept is:

> **Max backups = number of old rotated log files to retain.**

##### `--audit-log-max-size`

Controls the maximum size of the audit log before rotation.

Example:

```yaml
--audit-log-max-size=100
```

The value as being in MB. 

Think:

```text
audit.log
   |
   | reaches configured size
   ↓
rotate
   ↓
new audit.log
```

##### Log Rotation — Easy Memory Trick

Remember:

```text
AGE      → How old?
BACKUPS  → How many old files?
SIZE     → How big?
```

So:

```text
--audit-log-max-age
        ↓
      days

--audit-log-max-backups
        ↓
      old files

--audit-log-max-size
        ↓
      MB
```

---

### Audit Event Delivery Modes

The transcript also discusses three modes:

```text
Batch
Blocking
BlockingStrict
```

These control how audit events are delivered. 

##### Batch Mode

Default mode.

Instead of sending each audit event individually, events can be accumulated and sent in batches.

Conceptually:

```text
Event 1 ─┐
Event 2 ─┼──> Batch ──> Backend
Event 3 ─┘
```

This can reduce the overhead of processing individual events.

##### Blocking Mode

In blocking mode, the API server waits while processing the audit event.

Conceptually:

```text
API request
    |
    v
Audit processing
    |
    v
Response
```

Blocking can block the API server response while an individual audit event is processed. 

##### BlockingStrict

This is the strictest behavior described.

If audit processing fails:

```text
Audit failure
      ↓
API request fails
```

`blocking-strict` can cause the entire API-server request to fail when audit processing fails. 

----

##### Enabling Auditing on kube-apiserver

For a kubeadm-style cluster, the API server manifest is generally:

```text
/etc/kubernetes/manifests/kube-apiserver.yaml
```

You need to configure:

```text
1. Audit policy
2. Audit log path
3. Log rotation settings
4. Volume mounts
5. Volumes
```

Add the appropriate flags to the kube-apiserver command.

Before editing:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml \
   /etc/kubernetes/manifests/kube-apiserver.yaml.bak
```

If you break the configuration:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml.bak \
   /etc/kubernetes/manifests/kube-apiserver.yaml
```

Conceptually:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver

    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/etc/kubernetes/audit/logs/audit.log
    - --audit-log-max-age=...
    - --audit-log-max-backups=...
    - --audit-log-max-size=...
    volumeMounts:
    - name: audit
      mountPath: /etc/kubernetes/audit/policy.yaml
      readOnly: true
    - name: audit-log
      mountPath: /etc/kubernetes/audit/logs
      readOnly: false
  volumes:
  - name: audit
    hostPath:
      path: /etc/kubernetes/audit
  - name: audit-log
    hostPath:
      path: /etc/kubernetes/audit/logs
```

* Create the Audit Directory

  ```bash
  mkdir -p /etc/kubernetes/audit
  ```

* Then creates the policy:

  ```text
  /etc/kubernetes/audit/policy.yaml
  ```

* And a directory for logs:

  ```text
  /etc/kubernetes/audit/logs
  ```

  ```bash
  touch /etc/kubernetes/audit/logs/audit.log
  ```

**Example Policy**

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy

rules:

- level: Metadata
  resources:
  - group: ""
    resources:
    - secrets
  omitStages:
  - RequestReceived

- level: RequestResponse
  resources:
  - group: "apps"
    resources:
    - deployments
```

The important relationships are:

```text
Secrets
  ↓
core API group ("")
  ↓
Metadata

Deployments
  ↓
apps API group
  ↓
RequestResponse
```

---

### Testing the Audit Configuration

After the API server comes back:
```bash
kubectl get pods
```

Then inspect the audit log:
```bash
cat /etc/kubernetes/audit/logs/audit.log
```

or:
```bash
tail -f /etc/kubernetes/audit/logs/audit.log
```

You should start seeing audit events.

---

###  Test Secrets

Because the policy says:
```text
Secrets → Metadata
```
perform a Secret-related operation.

For example:
```bash
kubectl get secrets
```

Then inspect:
```bash
cat /etc/kubernetes/audit/logs/audit.log
```

You should see metadata information such as:
```text
user
verb
resource
timestamp
source IP
```

but not the full request/response bodies at Metadata level.

---

### Test Deployment Auditing

Create a Deployment.

For example:
```bash
kubectl create deployment demo --image=nginx
```

Then:
```bash
kubectl get pods
```

Now inspect:
```bash
cat /etc/kubernetes/audit/logs/audit.log
```

Because Deployments were configured at:
```text
RequestResponse
```

The event contains substantially more information.

---

### What Can You Learn From the Audit Entry?

```text
User
Source IP
Resource
Verb
Deployment name
Request information
Response information
```

For example:
```text
User:
kubernetes-admin

Verb:
create

Resource:
deployments

Group:
apps

Name:
demo
```

---

### Security Principle

A good audit policy follows:
> **Log enough information to investigate security events, but avoid unnecessary data and excessive log volume.**

For example:
```text
Secrets → Metadata
Deployments → RequestResponse
```
could make sense for a particular requirement.

Instead of:
```text
Everything → RequestResponse
```
which could generate massive logs.