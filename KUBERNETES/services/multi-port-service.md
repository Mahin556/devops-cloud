## Multi port service
- A Service can expose multiple ports (for apps that need HTTP + HTTPS, etc).
```yaml
apiVersion: v1
kind: Service
metadata:
  name: tutorial-point-service
spec:
  selector:
    application: my-application
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 31999
    - name: https
      protocol: TCP
      port: 443
      targetPort: 31998
```
- Each port must have a name when using multiple ports.
- Useful for applications exposing more than one protocol.
```bash
controlplane:~$ kubectl get svc
NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
tutorial-point-service   ClusterIP   10.103.25.44   <none>        80/TCP,443/TCP   3m47s
```