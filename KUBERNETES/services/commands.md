```bash
kubectl get pods --show-labels
kubectl apply -f service.yaml
kubectl get svc
kubectl get svc -l <lables>
kubectl get svc nginx -o wide
kubectl get endpoints
kubectl describe svc <svc_name>
kubectl describe endpoint <ep_name>
kubectl edit svc <name> #change type to LoadBalancer
kubectl api-resources | grep -i endpoints
kubectl api-resources | grep -i svc
kubectl expose <resource_type> <resource_name> --port=<port> --target-port=<targetPort> --type=<serviceType>
kubectl expose deployment nginx --port=80 --target-port=8080
kubectl patch svc my-app-lb -p '{"spec": {"type": "NodePort"}}'
kubectl expose deployment nginx --type=NodePort --port=8080 --target-port=80 #The Kubernetes API server handles the automatic assignment. When you create the NodePort service, the API server checks the available ports and allocates one that is not already in use by another service.
```