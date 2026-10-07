KUBERNETES/helm/examples/if-else/1.md```bash
helm version
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update nginx-stable
helm repo list/ls
helm repo search <keyword>
helm show chart nginx-stable/nginx-ingress
helm show values nginx-stable/nginx-ingress

helm install my-nginx-ingress nginx-stable/nginx-ingress \
  --namespace nginx-ingress \
  --set controller.replicaCount=2 \
  --set controller.service.type=NodePort \
  --set controller.service.httpPort.nodePort=30080 \
  --set controller.service.httpsPort.nodePort=30443

helm status my-nginx-ingress -n nginx-ingress

helm list -A

helm history my-nginx-ingress -n nginx-ingress

helm get manifest my-nginx-ingress -n nginx-ingress

cat <<EOF > /root/nginx-values.yaml
# Custom values for nginx-ingress
controller:
  replicaCount: 3
  
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
  
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
    annotations:
      service.kubernetes.io/app-name: "nginx-ingress-controller"
      
  metrics:
    enabled: true
    
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9113"
EOF

helm upgrade my-nginx-ingress nginx-stable/nginx-ingress \
  --namespace nginx-ingress \
  --values /root/nginx-values.yaml

helm upgrade my-nginx-ingress nginx-stable/nginx-ingress \
  --namespace nginx-ingress \
  --values /root/nginx-values.yaml

helm upgrade my-nginx-ingress nginx-stable/nginx-ingress \
  --namespace nginx-ingress \
  --set controller.image.tag="invalid-tag" \
  --set controller.replicaCount=5

helm rollback my-nginx-ingress 3 -n nginx-ingress #rollback to revision 3

# root@controlplane:~$ helm history my-nginx-ingress -n nginx-ingress
# REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION     
# 1               Thu Apr  9 12:17:12 2026        superseded      nginx-ingress-2.5.1     5.4.1           Install complete
# 2               Thu Apr  9 12:21:04 2026        superseded      nginx-ingress-2.5.1     5.4.1           Upgrade complete
# 3               Thu Apr  9 12:21:24 2026        superseded      nginx-ingress-2.5.1     5.4.1           Upgrade complete
# 4               Thu Apr  9 12:21:53 2026        superseded      nginx-ingress-2.5.1     5.4.1           Upgrade complete
# 5               Thu Apr  9 12:23:03 2026        deployed        nginx-ingress-2.5.1     5.4.1           Rollback to 3   

# root@controlplane:~$ helm get values my-nginx-ingress -n nginx-ingress
# USER-SUPPLIED VALUES:
# controller:
#   metrics:
#     enabled: true
#   podAnnotations:
#     prometheus.io/port: "9113"
#     prometheus.io/scrape: "true"
#   replicaCount: 3
#   resources:
#     limits:
#       cpu: 100m
#       memory: 128Mi
#     requests:
#       cpu: 50m
#       memory: 64Mi
#   service:
#     annotations:
#       service.kubernetes.io/app-name: nginx-ingress-controller
#       service.kubernetes.io/load-balancer-source-ranges: 10.0.0.0/8
#     nodePorts:
#       http: 30080
#       https: 30443
#     type: NodePort

helm get all my-nginx-ingress -n nginx-ingress


```