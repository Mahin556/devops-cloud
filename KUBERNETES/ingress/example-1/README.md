## Ingres controller
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
```
Deploy all in Ingress folder after creating below config map 

`kubectl create configmap nginx-config --from-file=nginx.conf`

ssh onto the node where the pod is deployed and the change the /etc/hosts file.



## Nodeport check via iptables
```
sudo iptables -t nat -L -n -v | grep -e NodePort -e KUBE
sudo iptables -t nat -L -n -v | grep 31188
```