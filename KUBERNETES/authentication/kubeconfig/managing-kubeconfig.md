### Viewing & Managing Your `kubeconfig`

Your `kubeconfig` file (typically at `~/.kube/config`) holds info about **clusters, users, contexts, and namespaces**. Avoid editing it manually—use `kubectl config` for safe, consistent changes.

> **Pro Tip:** Use `kubectl config -h` to explore powerful subcommands like `use-context`, `set-context`, `rename-context`, etc.

---

### Common `kubectl config` Commands (Compact View)

| Task                                      | Command & Example                                                                                                                                                                        |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| View current context                      | `kubectl config current-context`<br>Example: `seema@dev-cluster-context`                                                                                                                 |
| List all contexts                         | `kubectl config get-contexts`<br>Shows: `seema@dev-cluster-context`, etc.                                                                                                                |
| Switch to a different context             | `kubectl config use-context seema@prod-cluster-context`<br>Switches to prod                                                                                                              |
| View entire config (pretty format)        | `kubectl config view`<br>Readable view of clusters, users, contexts                                                                                                                      |
| View raw config (YAML for scripting)      | `kubectl config view --raw`<br>Useful for parsing/exporting                                                                                                                              |
| Show active config file path              | `echo $KUBECONFIG`<br>Defaults to `~/.kube/config` if not explicitly set                                                                                                                 |
| Set default namespace for current context | `kubectl config set-context --current --namespace=app1-staging-ns`<br>Updates Seema's current context                                                                                    |
| Override namespace just for one command   | `kubectl get pods --namespace=app1-prod-ns`<br>Runs the command in prod namespace                                                                                                        |
| Inspect kubeconfig at custom path         | `kubectl config view --kubeconfig=~/kubeconfigs/custom-kubeconfig.yaml`                                                                                                                  |
| Add a new user                            | `kubectl config set-credentials varun --client-certificate=varun-cert.pem --client-key=varun-key.pem --kubeconfig=~/kubeconfigs/seema-kubeconfig.yaml`                                   |
| Add a new cluster                         | `kubectl config set-cluster dev-cluster --server=https://dev-cluster-api-server:6443 --certificate-authority=ca.crt --embed-certs=true --kubeconfig=~/kubeconfigs/seema-kubeconfig.yaml` |
| Add a new context                         | `kubectl config set-context seema@dev-cluster-context --cluster=dev-cluster --user=seema --namespace=app1-dev-ns --kubeconfig=~/kubeconfigs/seema-kubeconfig.yaml`                       |
| Rename a context                          | `kubectl config rename-context seema@dev-cluster-context seema@dev-env`                                                                                                                  |
| Delete a context                          | `kubectl config delete-context seema@staging-cluster-context`                                                                                                                            |
| Delete a user                             | `kubectl config unset users.seema`                                                                                                                                                       |
| Delete a cluster                          | `kubectl config unset clusters.staging-cluster`                                                                                                                                          |
---

### Multiple Kubeconfig Files

```bash
kind create cluster --name=demo1
kind create cluster --name=demo2
```

Kubernetes supports multiple config files. Use `--kubeconfig` with any `kubectl` command to specify which one to use:

```bash
kubectl get pods --kubeconfig=~/.kube/dev-kubeconfig
kubectl config use-context dev-cluster --kubeconfig=~/.kube/dev-kubeconfig
```

Ideal for managing multiple clusters (e.g., dev/staging/prod) cleanly.

---

### Using a Custom Kubeconfig as Default via `KUBECONFIG`

By default, `kubectl` uses the kubeconfig file at `~/.kube/config`. You won't see anything with `echo $KUBECONFIG` unless you've set it yourself.

To avoid specifying `--kubeconfig` with every command, you can set the `KUBECONFIG` environment variable:

**Step-by-step:**

1. Open your shell profile:

   ```bash
   vi ~/.bashrc   # Or ~/.zshrc, depending on your shell
   ```

2. Add the line:

   ```bash
   export KUBECONFIG=$HOME/.kube/my-2nd-kubeconfig-file
   ```

3. Apply the change:

   ```bash
   source ~/.bashrc
   ```

Now, `kubectl` will automatically use that file for all commands.

---

### Merging a kubeconfig file
```bash
export KUBECONFIG=~/.kube/kubeconfig-1:~/.kube/kubeconfig-2
unset KUBECONFIG

kubectl config view --flatten > ~/.kube/config 
#view → shows combined configuration
#--flatten → removes duplicate certificates and embeds data directly
#output → redirected into a single kubeconfig file
#After this, you’ll have one unified kubeconfig at:
~/.kube/config
#This new file contains all: clusters, contexts, users from all the kubeconfig files you referenced.

#You can merge all three configs into a single file using the following command. Ensure you are running the command from the HOME/ .kube directory.
KUBECONFIG=config:dev_config:test_config kubectl config view --merge --flatten > config.new
mv $HOME/.kube/config $HOME/.kube/config.old
mv $HOME/.kube/config.new $HOME/.kube/config

kubectl config view --minify
```

---

### Adding Entries to a Kubeconfig File

Avoid manually editing the kubeconfig. Instead, use `kubectl config` to manage users, clusters, and contexts.

**Add a new user:**

```bash
kubectl config set-credentials varun \
  --client-certificate=~/kubeconfigs/varun-cert.pem \
  --client-key=~/kubeconfigs/varun-key.pem \
  --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-file

kubectl config set-credentials production-admin --token=cfrDHdb2 #Add user
#Token-based auth is the correct method when your user is a service account created within Kubernetes. Use --username and --password instead if you’re using HTTP Basic Auth, or set --client-certificate and --client-key for certificate-based authentication.

```

**Add a new cluster:**

```bash
kubectl config set-cluster aws-cluster \
  --server=https://aws-api-server:6443 \
  --certificate-authority=~/kubeconfigs/aws-ca.crt \
  --embed-certs=true \
  --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-
  
kubectl config set-cluster production --server=https://1.1.1.1 --certificate-authority=~/.kube/production.ca.crt #Add cluster to the config

kubectl config set-cluster staging --server=https://2.2.2.2 --certificate-authority=~/.kube/staging.ca.crt

#If you’re running a local cluster without TLS, you can disable TLS verification instead of supplying certificate authority data:
kubectl config set-cluster staging --server=https://2.2.2.2 --insecure-skip-tls-verify
```

**Add a new context:**

```bash
kubectl config set-context production --cluster production --user production-admin 

kubectl config set-context varun@aws-cluster-context \
  --cluster=aws-cluster \
  --user=varun \
  --namespace=default \
  --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-file
```

**Switch to the new context:**

```bash
kubectl config use-context varun@aws-cluster-context \
  --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-file
```
**Verify:**



```bash
kubectl config view --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-file --minify
```
 * `--kubeconfig=...`: Points to your custom kubeconfig file.
 * `--minify`: Shows only the active context and related cluster/user info.
 
```bash
kubectl config view --kubeconfig=~/kubeconfigs/my-2nd-kubeconfig-file
```

**Verify cluster & context**
```bash
kubectl config view
kubectl config view --raw
kubectl config view --kubeconfig=<path_to_kubeconfig>

kubectl config get-contexts <context-name>
kubectl config get-contexts -o=name

kubectl config use-context <context-name>
kubectl cluster-info
kubectl cluster-info --kubeconfig=<path_to_kubeconfig>

kubectl config get-users #list users

kubectl get pods --context production #change context for this command

kubectl config delete-user staging-admin
kubectl config delete-context staging-context
kubectl config delete-cluster staging-cluster
```

---


**Get the user from the context**
```bash
kubectl config view -o jsonpath='{.contexts[?(@.name=="<context_name>")].context.user}'
```

**Get the client certificate path for the minikube user**
```bash
kubectl config view -o jsonpath='{.users[?(@.name=="<user_name>")].user.client-certificate}'

kubectl config view -o jsonpath='{.users[?(@.name=="<user_name>")].user.client-certificate}' > <user_name>.crt
```

**View the full x509 certificate details:**
```bash
openssl x509 -in <user_name>.crt -text -noout
```

---

**Verifying Certificate**
```bash
openssl x509 -in <user_name>.crt -text -noout | grep Subject | grep -v "Public Key Info"
```

---

**Creating a User in kubeconfig file**

```bash
# Default kubeconfig file
kubectl config set-credentials jane --client-certificate=jane.crt --client-key=jane.key

kubectl config set-credentials <user_name> --client-key=<user_name>.key --client-certificate=<user_name>.crt --embed-certs=true

# Custome Kubeconfig file
kubectl config set-credentials <user_name> --client-key=<user_name>.key --client-certificate=<user_name>.crt --embed-certs=true --kubeconfig=<path>
```

---

**Creating a User in kubeconfig file**
```bash
# Default kubeconfig file
kubectl config set-context <context_name> --cluster=minikube --user=<user_name>

# Custome Kubeconfig file
kubectl config set-context <context_name> --cluster=minikube --user=<user_name> --kubeconfig=<path>
```
