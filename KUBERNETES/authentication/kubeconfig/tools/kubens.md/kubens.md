* Switch Between Namespaces Quickly
* Install kubens (via Krew — recommended)
```bash
#Step 1: Install Krew
#(Use install script from official site)
https://krew.sigs.k8s.io/docs/user-guide/setup/install/

#Step 2: Install the plugins
kubectl krew install ns
```
```bash
kubectl ns #List all namespaces

kubectl ns default #Switch namespace
```