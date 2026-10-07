### Static Password File (Basic Auth)

This is one of the simplest and oldest forms of authentication, mostly used for testing or very early setups.

* It is a **CSV file** that contains entries like:
  ```
  password,username,uid,"group1,group2"
  ```
  Example:
  ```
  mypass,varun,uid123,"devs,admins"
  ```

* This file is supplied to the API server using the flag:
  ```
  --basic-auth-file=/etc/kubernetes/auth.csv
  ```

* The API server must be **restarted** for changes to take effect.
  If you’re using **kubeadm**, editing the static pod manifest at `/etc/kubernetes/manifests/kube-apiserver.yaml` will trigger an automatic restart.

* You can use these credentials with tools like `curl`:
  ```bash
  curl -u varun:mypass https://<cluster-endpoint>/api
  ```

* ❌ **Not recommended** in production because:
  * The file is in **plain text**
  * No token rotation
  * No auditability