#### Affinity
* `nodeSelector`: Simple equality-based matching (`key=value`). Very limited.
* `nodeAffinity`: More expressive, supports operators (`In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`)

* `requiredDuringSchedulingIgnoredDuringExecution`: **Hard rule** – if no node matches, the Pod won’t be scheduled.
* `preferredDuringSchedulingIgnoredDuringExecution`: **Soft rule** – scheduler tries to place Pods there, but falls back if unavailable.

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: type
          operator: In
          values:
          - platform-tools
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      preference:
        matchExpressions:
        - key: instance-type
          operator: In
          values:
          - t2.large
```
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
  labels:
    app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: type
                operator: In
                values:
                - platform-tools
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: instance-type
                operator: In
                values:
                - t2.large
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```
* You can combine **affinity** + **tolerations** in DaemonSets.