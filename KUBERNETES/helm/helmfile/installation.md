### Installation
```bash
wget https://github.com/helmfile/helmfile/releases/download/v1.7.4/helmfile_1.7.4_linux_amd64.tar.gz

tar -xzf helmfile_1.7.4_linux_amd64.tar.gz

sudo install -m 755 helmfile /usr/local/bin/helmfile
```
```bash
helmfile --version
```

---

### Docker(alternative)
```bash
docker run --rm --net=host -v "${HOME}/.kube:/root/.kube"  \
-v "${HOME}/.config/helm:/root/.config/helm"  \
-v "${PWD}:/wd"  \
--workdir /wd quay.io/roboll/helmfile:helm3-v0.135.0 helmfile sync 
```