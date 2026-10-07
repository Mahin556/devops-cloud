```bash
git clone https://github.com/Mahin556/Helm-charts.git

cd Helm-charts

helm create go-portfolio-app

apt install tree

tree
# .
# |-- README.md
# `-- go-portfolio-app
#     |-- Chart.yaml
#     |-- charts
#     |-- templates
#     |   |-- NOTES.txt
#     |   |-- _helpers.tpl
#     |   |-- deployment.yaml
#     |   |-- hpa.yaml
#     |   |-- httproute.yaml
#     |   |-- ingress.yaml
#     |   |-- service.yaml
#     |   |-- serviceaccount.yaml
#     |   `-- tests
#     |       `-- test-connection.yaml
#     `-- values.yaml

cd go-portfolio-app

rm -rf templates/* values.yaml

cd templates/


cat << EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata: 
  name: {{ .Release.Name }}-{{ .Values.namespace }}
EOF

cat << EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Values.appname }}-deployment
  namespace: {{ .Release.Name }}-{{ .Values.namespace }}
  labels:
    role: {{ .Values.labels.role }}
    env: {{ .Values.labels.env }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      role: {{ .Values.labels.role }}
      env: {{ .Values.labels.env }}
  template:
    metadata:
      labels:
        role: {{ .Values.labels.role }}
        env: {{ .Values.labels.env }}
    spec:
      containers:
      - name: {{ .Values.containers.name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ default 8080 (index .Values.containers.ports 0).port }}
        resources:
          requests:
            memory: {{ .Values.containers.requests.memory }}
            cpu: {{ .Values.containers.requests.cpu }}
          limits:
            memory: {{ .Values.containers.limits.memory }}
            cpu: {{ .Values.containers.limits.cpu }}
EOF

cat << EOF > service.yaml
apiVersion: v1
kind: Service
metadata: 
  name: {{ .Release.Name }}-{{ .Values.appname }}-service
  namespace: {{ .Release.Name }}-{{ .Values.namespace }}
spec:
  type: ClusterIP
  ports:
    - port: {{ default 8080 (index .Values.containers.ports 0).port }}
      targetPort: {{ default 8080 (index .Values.containers.ports 0).targetPort }}
  selector:
    role: {{ .Values.labels.role }}
    env: {{ .Values.labels.env }}
EOF

cd ..

cat << EOF > values.yaml
appname: go-portfolio
namespace: go-portfolio-namespace
replicaCount: 3

labels:
  role: go-portfolio
  env: dev

image:
  pullPolicy: IfNotPresent
  repository: avian19/go-port
  tag: "10201891038"

containers:
  name: go-portfolio
  ports:
    - port: 8080
      targetPort: 8080
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"
    cpu: "1"
EOF

helm install demo .

kubectl patch svc demo-go-portfolio-service -n demo-go-portfolio-namespace -p '{"spec": {"type": "NodePort"}}'

git add .

git config --global user.email "mahinraza556@gmail.com"

git config --global user.name "Mahin556"

git commit -m "Update the go-portfolio-app"

git push

git checkout -b gh-pages #To Package your Helm Chart and publish it, the gh-pages branch is required in our GitHub Repo. So, create a branch called gh-pages

git checkout main

helm package go-portfolio-app/

touch index.yaml #To publish, we need to create an index.yaml file that keeps track of all the packaged helm charts whenever you install them.

cat index.yaml

helm repo index .

cat index.yaml #Now, Index.yaml is not empty as it holds the chart name go-portfolio-app

git add .

git commit -m "updated"

git push origin gh-pages
#Go to the browser and check the GitHub repository, you will see there will a GitHub Actions workflow getting triggered in Orange color.

#Go to the Settings of your GitHub repository and navigate to Pages where we are hosting our helm charts
#As you can see in the below snippet, Your site is live at https://mahin556.github.io/Helm-charts/. This will be our URL to deploy Helm charts on any Kubernetes Cluster.

helm repo add mahin-repo https://mahin556.github.io/Helm-charts/

helm install demo mahin-repo/go-portfolio-app

helm repo list

kubectl get all -n demo-go-portfolio-namespace

ssh -L 8080:localhost:8080 <ec2-user>@<public-ip> -i <Pem-file> #Create a local port-forward tunnel
```

---
---

```bash
git clone https://github.com/Mahin556/Helm-charts.git

cd Helm-charts

helm create tetris-game

apt install tree

tree
# .
# |-- README.md
# `-- go-portfolio-app
#     |-- Chart.yaml
#     |-- charts
#     |-- templates
#     |   |-- NOTES.txt
#     |   |-- _helpers.tpl
#     |   |-- deployment.yaml
#     |   |-- hpa.yaml
#     |   |-- httproute.yaml
#     |   |-- ingress.yaml
#     |   |-- service.yaml
#     |   |-- serviceaccount.yaml
#     |   `-- tests
#     |       `-- test-connection.yaml
#     `-- values.yaml

cd tetris-game

rm -rf templates/* values.yaml

cd templates/

cat << EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata: 
    name: {{ .Release.Name }}-{{ .Values.namespace }}
EOF


cat << EOF > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-{{ .Values.appname }}-deployment
  namespace: {{ .Release.Name }}-{{ .Values.namespace }}
  labels:
    role: {{ .Values.labels.role }}
    env: {{ .Values.labels.env }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      role: {{ .Values.labels.role }}
      env: {{ .Values.labels.env }}
  template:
    metadata:
      labels:
        role: {{ .Values.labels.role }}
        env: {{ .Values.labels.env }}
    spec:
      containers:
      - name: {{ .Values.containers.name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ default 8080 (index .Values.containers.ports 0).port }}
        resources:
          requests:
            memory: {{ .Values.containers.requests.memory }}
            cpu: {{ .Values.containers.requests.cpu }}
          limits:
            memory: {{ .Values.containers.limits.memory }}
            cpu: {{ .Values.containers.limits.cpu }}
EOF

cat << EOF > service.yaml
apiVersion: v1
kind: Service
metadata: 
  name: {{ .Release.Name }}-{{ .Values.appname }}-service
  namespace: {{ .Release.Name }}-{{ .Values.namespace }}
  labels:
    role: {{ .Values.labels.role }}
    env: {{ .Values.labels.env }}
spec:
  type: ClusterIP
  ports:
    - port: {{ default 8080 (index .Values.containers.ports 0).port }}
      targetPort: {{ default 8080 (index .Values.containers.ports 0).targetPort }}
  selector:
    role: {{ .Values.labels.role }}
    env: {{ .Values.labels.env }}
EOF

cd ..

cat << EOF > values.yaml
appname: tetris-game

namespace: tetris-game-ns
replicaCount: 2

labels:
  role: tetris-game
  env: dev

image:
  pullPolicy: IfNotPresent
  repository: avian19/tetrisv2
  tag: "1"

containers:
  name: tetris-game
  ports:
    - port: 3000
      targetPort: 3000
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "512Mi"
    cpu: "1"
EOF

helm install demo1 .

helm uninstall demo1

git add .

git config --global user.email "mahinraza556@gmail.com"

git config --global user.name "Mahin556"

git commit -m "Adding tetris-game YAMLs"

git push origin main

helm package tetris-game/

tree

#Now, switch to gh-pages to package the helm chart and publish it
git switch gh-pages

git status

cat index.yaml

helm repo index .

cat index.yaml

git add .

git commit -m "Added a tetris app to helm chart"

git push origin gh-pages 

#As soon as you push your changes to the GitHub repo.
#Go to the browser and check the GitHub repository, you will see there will a GitHub Actions workflow getting triggered in Orange color.
#You can check the process of deployments by clicking on the Orange icon
#You can also go to Actions to view the GitHub workflow
#Now, when you are trying to install the Tetris app you might get errors as the old chart doesn't have Tetris application configuration including index.yaml file.
helm install tetris mahin-repo/tetris-game #Error, because this repo not have helm chart updated

helm repo update

helm install tetris mahin-repo/tetris-game

kubectl get all -n tetris

ssh -L 3000:localhost:3000 <ec2-user>@<public-ip> -i <Pem-file>

kubectl patch svc demo1-tetris-game-service -n demo1-tetris-game-ns -p '{"spec": {"type": "NodePort"}}'

helm repo add mahin-repo https://mahin556.github.io/Helm-charts/

```