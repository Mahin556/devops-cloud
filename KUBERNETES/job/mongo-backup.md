* `kubectl apply -f job.yaml`

* `kubectl get jobs`

* `kubectl get pods`

* `kubectl get pv`

* `kubectl describe pv <pv-name>`

* `minikube ssh`

* `ls <host-path-from-pv>`

* `kubectl exec -it <mongodb-pod-name> -- mongo`

* `show dbs`

* `use admin`

* `show collections`

* `exit`

* `kubectl get jobs` (again to verify TTL cleanup)

* `kubectl get pods` (to verify job pod deletion)

* `kubectl apply -f cronjob.yaml`

* `kubectl get cj`  *(cronjobs short name)*

* `kubectl get jobs`

* `watch kubectl get jobs` *(used to continuously monitor job creation)*

* `kubectl edit cronjob <cronjob-name>`

* `kubectl patch cronjob <cronjob-name> -p '{"spec":{"suspend":true}}'`

* `kubectl get cj`

* `kubectl get jobs`

* `kubectl patch cronjob <cronjob-name> -p '{"spec":{"suspend":false}}'`

* `kubectl get jobs`

* `kubectl delete cronjob <cronjob-name>`

* `kubectl get jobs` (confirm all jobs removed)
