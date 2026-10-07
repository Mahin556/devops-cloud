```bash
kubectl exec -n platform pods/config-service-6fbbc5b48f-9sj8d -- tar -chf
 - -C /app/config . | tar -xf - -C /home/laborant/config/
```