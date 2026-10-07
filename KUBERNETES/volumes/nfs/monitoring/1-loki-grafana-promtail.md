### Kubernetes + Loki (for log management)

#### Prereq
```bash
#Install go
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.6.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc 
source ~/.bashrc 
echo $PATH
#/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/go/bin

#Deploy kind load balancer controller on host
go install sigs.k8s.io/cloud-provider-kind@latest

#Run Kind LoadBalancer Controller in Backgroud
sudo nohup ~/go/bin/cloud-provider-kind > kind-lb.log 2>&1 &
```

#### Add Grafana repo
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm search repo loki  # we will use grafana/loki stack
```

#### Create custom values for loki
```bash
helm show values grafana/loki-stack > loki-values.yaml

cat > loki-values.yaml <<'EOF'

#FILE START HERE

test_pod:
  enabled: true
  image: bats/bats:1.8.2
  pullPolicy: IfNotPresent

loki:
  enabled: true
  isDefault: true
  url: http://{{(include "loki.serviceName" .)}}:{{ .Values.loki.service.port }}
  readinessProbe:
    httpGet:
      path: /ready
      port: http-metrics
    initialDelaySeconds: 45
  livenessProbe:
    httpGet:
      path: /ready
      port: http-metrics
    initialDelaySeconds: 45
  datasource:
    jsonData: "{}"
    uid: ""


promtail:
  enabled: true
  config:
    logLevel: info
    serverPort: 3101
    clients:
      - url: http://{{ .Release.Name }}:3100/loki/api/v1/push

fluent-bit:
  enabled: false

grafana:
  enabled: true
  sidecar:
    datasources:
      label: ""
      labelValue: ""
      enabled: true
      maxLines: 1000
  image:
    tag: 10.3.3
  service:
    type: LoadBalancer
    # type: NodePort

prometheus:
  enabled: false
  isDefault: false
  url: http://{{ include "prometheus.fullname" .}}:{{ .Values.prometheus.server.service.servicePort }}{{ .Values.prometheus.server.prefixURL }}
  datasource:
    jsonData: "{}"

filebeat:
  enabled: false
  filebeatConfig:
    filebeat.yml: |
      # logging.level: debug
      filebeat.inputs:
      - type: container
        paths:
          - /var/log/containers/*.log
        processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
      output.logstash:
        hosts: ["logstash-loki:5044"]

logstash:
  enabled: false
  image: grafana/logstash-output-loki
  imageTag: 1.0.1
  filters:
    main: |-
      filter {
        if [kubernetes] {
          mutate {
            add_field => {
              "container_name" => "%{[kubernetes][container][name]}"
              "namespace" => "%{[kubernetes][namespace]}"
              "pod" => "%{[kubernetes][pod][name]}"
            }
            replace => { "host" => "%{[kubernetes][node][name]}"}
          }
        }
        mutate {
          remove_field => ["tags"]
        }
      }
  outputs:
    main: |-
      output {
        loki {
          url => "http://loki:3100/loki/api/v1/push"
          #username => "test"
          #password => "test"
        }
        # stdout { codec => rubydebug }
      }

# proxy is currently only used by loki test pod
# Note: If http_proxy/https_proxy are set, then no_proxy should include the
# loki service name, so that tests are able to communicate with the loki
# service.
proxy:
  http_proxy: ""
  https_proxy: ""
  no_proxy: ""


#FILE ENDS HERE
#KEY POINTS IN loki-values.yaml file
EOF
```

1. Loki is enabled and configured with readiness and liveness probes for health checking.
2. Promtail is enabled to forward logs from Kubernetes nodes to Loki.
3. Grafana is enabled with a NodePort service to allow access to the Grafana UI from outside the cluster.
4. Prometheus, Filebeat, and Logstash are explicitly disabled.


#### Deploy Helm chart
```bash
helm upgrade --install --values loki-values.yaml loki grafana/loki-stack -n grafana-loki --create-namespace
```

#### Check all pods are running
```bash
kubectl get pods -n grafana-loki
```

#### Deploy a application which will generate logs after every 5 seconds

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-generator
  namespace: default
  labels:
    app: log-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-generator
  template:
    metadata:
      labels:
        app: log-generator
    spec:
      containers:
        - name: log-generator
          image: busybox
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-c"]
          args:
            - >
              while true; do
                ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ");
                echo "{\"timestamp\":\"${ts}\",\"level\":\"info\",\"message\":\"Hello from log-generator! Testing Loki JSON logs.\"}";
                sleep 5;
              done
          resources:
            limits:
              cpu: "100m"
              memory: "64Mi"
            requests:
              cpu: "50m"
              memory: "32Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: log-generator
  namespace: default
  labels:
    app: log-generator
spec:
  selector:
    app: log-generator
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
EOF
```

<!-- 
#### Find the nodeport assigned to Grafana
```bash
kubectl get svc loki-grafana -n grafana-loki  -o jsonpath="{.spec.ports[0].Loadbalancer}"
``` -->


#### Export LB servicee from kind cluster
```bash
yum install -y socat
LB_IP=$(kubectl get -n vgrafana-loki svc/loki-grafana -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $LB_IP
sudo socat TCP-LISTEN:81,fork TCP:$LB_IP:80 
```

#### Access Grafana
```bash
http://<IP>:<NODE-PORT>
```

### Get grafana username / password
```bash
kubectl get secret loki-grafana -n grafana-loki -o jsonpath="{.data.admin-user}" | base64 --decode
kubectl get secret loki-grafana -n grafana-loki -o jsonpath="{.data.admin-password}" | base64 --decode
```

#### Check connection -> data source
```bash
<you should see loki>

Select "explore" run query

=================================
Loki uses LogQL language for logs
=================================

Example #1 - Select all logs from namespace default

{namespace="default"}

Example #2 - Select logs from pods having label "app=my-service" from default namespace

{app="my-service", namespace="default"}

Example #3 - Get logs from pods having label "app=my-service" from default namespace having word curl 

{app="my-service", namespace="default"} |= "curl"

Example #4 - Get logs from pods having label "app=my-service" from default namespace not having work curl 

{app="my-service", namespace="default"} != "curl"

Example #5 - Select logs from webapp container in prod namespace having word curl

{pod="webapp",namespace="prod"} |= "curl" 
{pod="multi",container="boxone", namespace="prod"}

Example #6 - Checking events

{source="event-exporter"}
{source="event-exporter"} |= "Failed"

Example #7 - Get logs of a particular node

{node_name="your-node-name"}
```

### Choose Loki when ###

You want a simple, scalable, and cost-effective logging solution.
You’re operating in a cloud-native environment.
You’re already using Grafana and Prometheus.
Your log analysis needs are straightforward.


### References:
- https://medium.com/@muppedaanvesh/a-hands-on-guide-to-kubernetes-logging-using-grafana-loki-%EF%B8%8F-b8d37ea4de13