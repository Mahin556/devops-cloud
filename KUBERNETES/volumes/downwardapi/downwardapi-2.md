* **Demo: downwardAPI - Files via Volumes**

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
    name: downwardapi-volume
      labels:
        app: good_app
        owner: hr
      annotations:
        version: "good_version"
    spec:
    containers:
    - name: metadata-container
        image: busybox
        command: ["/bin/sh", "-c", "cat /etc/podinfo/* && sleep 3600"]
        # The container will display the contents of all files under /etc/podinfo (i.e., metadata)
        # and then sleep for an hour, keeping the pod alive for verification.
        volumeMounts:
        - name: downwardapi-volume
          mountPath: /etc/podinfo
        # Mounts the downward API volume at /etc/podinfo inside the container.
    volumes:
    - name: downwardapi-volume
        downwardAPI:
        items:
        - path: "labels"
            fieldRef:
            fieldPath: metadata.labels
            # Writes the Pod's labels to a file named 'labels' under /etc/podinfo.
        - path: "annotations"
            fieldRef:
            fieldPath: metadata.annotations
            # Writes the Pod's annotations to a file named 'annotations' under /etc/podinfo.

    ```
    ```bash
    kubectl exec -it downwardapi-volume -- /bin/sh #When you exec by default it would take you to the first container
    ```
    ```bash
    cd /etc/podinfo
    ls -l
    ```
    You should see symbolic links:
    ```bash
    annotations -> ..data/annotations
    labels -> ..data/labels
    ```
    * These links are created because Kubernetes uses a [projected volume](https://kubernetes.io/docs/concepts/storage/volumes/#projected) with the Downward API, which manages file updates using symlinks pointing to the `..data/` directory. This allows for atomic updates.
    * Check the content of each file:
        ```bash
        cat labels
        ```
    * Expected output:
        ```bash
        app="good_app"
        owner="hr"
        ```

        ```bash
        cat annotations
        ```
    * Expected output:
        ```bash
        version="good_version"
        ```
    * These values are directly fetched from the pod’s metadata and written to files using the Downward API.
    * Since the pod's container command was set to:
        ```yaml
        command: ["/bin/sh", "-c", "cat /etc/podinfo/* && sleep 3600"]
        ```
    * The contents of `/etc/podinfo/labels` and `/etc/podinfo/annotations` will be printed in the pod's logs when it starts. To view them:
        ```bash
        kubectl logs downwardapi-volume
        ```
    * Expected output:
        ```bash
        app="good_app"
        owner="hr"
        version="good_version"
        ```
    * This further confirms that the Downward API volume successfully mounted the metadata into the container at runtime.
