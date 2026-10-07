- We can Pass the environment variable inside the container in Pods.
- Environment variables for Pods are defined inside .spec.containers[*].env or .spec.containers[*].envFrom.
- Two ways to define environment variables
    - env → define key-value pairs directly in the Pod manifest.
    - envFrom → load key-value pairs from a ConfigMap or Secret.
- Variables defined via env or envFrom override image defaults.
- Variable names must be valid ASCII characters (except =).

### Direct environment variables (env)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envar-demo
  labels:
    purpose: demonstrate-envars
spec:
  containers:
  - name: envar-demo-container
    image: gcr.io/google-samples/hello-app:2.0
    env:
    - name: DEMO_GREETING
      value: "Hello from the environment"
    - name: DEMO_FAREWELL
      value: "Such a sweet sorrow"
```
```bash
kubectl apply -f https://k8s.io/examples/pods/inject/envars.yaml
kubectl get pods -l purpose=demonstrate-envars
kubectl exec envar-demo -- printenv
```

### Using environment variables in container commands

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: print-greeting
spec:
  containers:
  - name: env-print-demo
    image: bash
    env:
    - name: GREETING
      value: "Warm greetings to"
    - name: HONORIFIC
      value: "The Most Honorable"
    - name: NAME
      value: "Kubernetes"
    - name: MESSAGE
      value: "$(GREETING) $(HONORIFIC) $(NAME)"
    command: ["echo"]
    args: ["$(MESSAGE)"]
```

### Using env with a literal value
- Simplest way
- Static value
- Hard-coded; cannot change without redeploying the Pod.
```yaml
env:
  - name: APP_MODE
    value: "production"
  - name: LOG_LEVEL
    value: "debug"
```

### Using env with fieldRef (Downward API)
- Fetch info about the pod and container from the specification itself
- Used when container need to knwo it's own metadata
- Dynamic, automatically populated.
- Limited to Pod metadata and resource info.
```yaml
env:
  - name: MY_POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: MY_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: MY_NODE
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

### Using env with resourceFieldRef
- Exposes container resource requests/limits as env vars.
- Applications need CPU/memory limits to configure themselves.
- Dynamic
```yaml
env:
  - name: CPU_REQUEST
    valueFrom:
      resourceFieldRef:
        resource: requests.cpu
  - name: MEM_LIMIT
    valueFrom:
      resourceFieldRef:
        resource: limits.memory
```

### Using env with configMapKeyRef (single key from ConfigMap)
- Maps one ConfigMap key to an env var.
- Configurable settings that may change between environments.
```yaml
env:
  - name: APP_MODE
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: APP_MODE
```

### Using envFrom: configMapRef (all keys from ConfigMap)
- Maps all keys in a ConfigMap as environment variables automatically.
- Inject multiple configuration settings at once.
- Reduce YAML Repetition.
- Inject multiple vars.
- Cannot rename keys; all keys become env vars as-is.
```yaml
envFrom:
  - configMapRef:
      name: my-config
```

### Using env with secretKeyRef (single key from Secret)
- Maps one Secret key to an environment variable.
- Database credentials, API keys, passwords, tokens, TlS certiricates.
- Secrets are base64-decoded automatically.
- Keeps sensitive info out of YAML.
```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: DB_USER
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: DB_PASS
```

### Using envFrom: secretRef (all keys from Secret)
- Maps all keys in a Secret as env vars.
- Inject multiple secrets at once (like DB credentials + tokens).
- Cannot rename keys.
```yaml
envFrom:
  - secretRef:
      name: my-secret
```

### Using env with configMapKeyRef or secretKeyRef + optional: true
- Marks the key as optional to avoid Pod creation failure if key is missing.
- Some keys may not exist in all environments.
```yaml
env:
  - name: OPTIONAL_VAR
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: SOME_KEY
        optional: true
```

### Using env with value + substitution (mixing Downward API)
- You can use Downward API inside literals via valueFrom.
- Combine static and dynamic values.
- Some shells may require envsubst for more complex substitutions.
```yaml
env:
  - name: GREETING
    value: "Hello from Pod $(MY_POD_NAME)"
  - name: MY_POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
```

### Using command / args to inject environment variables dynamically
- Can also pass env vars directly to the container process.
- Temporary scripts or testing.
```yaml
command: ["sh", "-c"]
args:
  - echo "DB_USER is $DB_USER"
```

### Using volumeMounts for Secrets/ConfigMaps as files
- Not strictly env, but an alternative: applications can read env-like config from mounted files.
- Each key becomes a file.
```yaml
volumes:
  - name: config-vol
    configMap:
      name: my-config
volumeMounts:
  - name: config-vol
    mountPath: /etc/config
```
Can be combined with env if needed:
```yaml
env:
  - name: APP_MODE
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: APP_MODE
```


### References:
- https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/
