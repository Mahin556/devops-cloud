```bash
helm create helloworld1

helm create helloworld2

cat <<EOF > helmfile.yaml
---
releases:

  - name: helloworld1
    chart: ./helloworld1
    installed: true

  - name: helloworld2
    chart: ./helloworld2
    installed: true
EOF

helmfile sync  

```