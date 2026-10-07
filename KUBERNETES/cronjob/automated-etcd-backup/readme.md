```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml
```

Find the exact certificate paths and endpoint used by the running etcd pod:

```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml
```

Look for `--cert-file`, `--key-file`, `--trusted-ca-file`, and `--advertise-client-urls`. 

These values go directly into the CronJob container args.

```bash
kubectl create job --from=cronjob/etcd-backup etcd-backup-manual-test -n kube-system
```
```bash
kubectl get job etcd-backup-manual-test -n kube-system
kubectl logs -l job-name=etcd-backup-manual-test -n kube-system
ls -lh /home/laborant/etcd-backup/
```