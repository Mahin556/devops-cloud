* These tools are extremely helpful when working with multiple clusters (dev, stage, prod) and multiple namespaces.
* Install kubectx(via Krew — recommended)
```bash
#Step 1: Install Krew
#(Use install script from official site)
https://krew.sigs.k8s.io/docs/user-guide/setup/install/

#Step 2: Install the plugins
kubectl krew install ctx
```
```bash
kubectl ctx #List all context
kubectl ctx production #Switch context
```