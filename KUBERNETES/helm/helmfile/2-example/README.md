```bash
cat <<EOF > helmfile.yaml
---
repositories:
  - name: helloworld
    url: git+https://github.com/rahulwagh/helmchart@helloworld?ref=master&sparse=0
releases:
  - name: helloworld
    chart: helloworld/helloworld
    installed: false 
EOF

helm plugin list

helm plugin install https://github.com/aslafy-z/helm-git --version 1.5.2 --verify=false

helm plugin list

helmfile sync

cat <<EOF > helmfile.yaml
---
repositories:
  - name: helloworld
    url: git+https://github.com/rahulwagh/helmchart@helloworld?ref=master&sparse=0
releases:
  - name: helloworld
    chart: helloworld/helloworld
    installed: true
EOF
```