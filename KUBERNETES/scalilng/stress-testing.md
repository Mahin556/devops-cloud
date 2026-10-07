### Stress Testing

- To see HPA in action, you can perform a stress test on your deployments. Here is an example of how to generate load on the Apache deployment using 'BusyBox':
```bash
kubectl run -i --tty load-generator --image=busybox /bin/sh
```

- Inside the container, use 'wget' to generate load:
```bash
while true; do wget -q -O- http://apache-service.default.svc.cluster.local; done
```

This will generate continuous load on the Apache service, causing the HPA to scale up the number of pods.

- Now to check if HPA worked or not, open a same new terminal and run the following command
```bash
kubectl get hpa -w
```

> Note: Wait for few minutes to get the status reflected.