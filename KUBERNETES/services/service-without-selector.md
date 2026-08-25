## Service without Selector
* You can create a Service without a selector.
* In this case, **Kubernetes does not automatically create Endpoints**.
* You must manually create `Endpoints` object.

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tutorial-point-service
spec:
  ports:
  - port: 8080
    targetPort: 80
```

And then define endpoints manually:

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: tutorial-point-service
subsets:
  - addresses:
      - ip: 192.168.1.4
      - ip: 192.168.0.4
    ports:
      - port: 80
```
- Use Case: Exposing an external database or service not managed by Kubernetes.