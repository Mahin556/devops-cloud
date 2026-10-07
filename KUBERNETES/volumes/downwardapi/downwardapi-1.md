* **Demo: downwardAPI - Environment variables**

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
    name: downwardapi-example
    labels:
        app: demo
    spec:
    containers:
    - name: metadata-container
        image: busybox
        command: ["/bin/sh", "-c", "env && sleep 3600"] 
        # The container prints all environment variables and then sleeps for 1 hour.
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        # Creates an environment variable named POD_NAME.
        # The value of this variable is set dynamically using the Downward API.
        # It pulls the Pod's name (in this case, "downwardapi-example") from its metadata.
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        # Creates an environment variable named POD_NAMESPACE.
        # The value of this variable is set dynamically using the Downward API.
        # It pulls the Pod's namespace (e.g., "default") from its metadata.
    ```

    ```bash
    kubectl exec downwardapi-example -- env | grep POD_
    ```

* You should see output like:
    ```bash
    POD_NAME=downwardapi-example
    POD_NAMESPACE=default #take from the namespace section which is auto field when not provided
    ```
    This confirms that:
    - `POD_NAME` is set to the Pod’s name.
    - `POD_NAMESPACE` is set to the namespace it's running in (usually `default`, unless specified otherwise).
