#### Service Account Tokens

* These are the **most commonly used tokens** for authenticating to the Kubernetes API server — both by **internal** and **external systems**.

* For **internal workloads**, the token is **automatically mounted** into Pods at:
  ```
  /var/run/secrets/kubernetes.io/serviceaccount/token
  ```

* For **external systems**, you can use the **TokenRequest API** to fetch a short-lived token tied to a specific ServiceAccount.

* These tokens are **JWTs** signed by the API server’s private key and **verified** using its public certificate authority (CA).

* They are **presented as bearer tokens** using the `Authorization` header:
  ```bash
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  curl -H "Authorization: Bearer $TOKEN" https://<cluster-endpoint>/
  
  curl -k -H "Authorization: Bearer $TOKEN" https://172.30.1.2:6443/api/v1/namespaces/default/pods

  curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $TOKEN" https://172.30.1.2:6443/api/v1/namespaes/default/pods

  curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $TOKEN" https://172.30.1.2:6443/api/v1/namespaces/$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)/pods
  ```

* ✅ This is the **preferred method** for authenticating both internal controllers and trusted external automation tools.

---

> **Note:**
> A **token** is a general term for any credential used to authenticate a user or system.
> A **bearer token** is a specific type of token used in HTTP authorization, where simply possessing the token is enough to gain access — no additional identity proof is required. In Kubernetes, ServiceAccount tokens are bearer tokens presented in API requests via the `Authorization: Bearer <token>` header.

>All ServiceAccount tokens are technically bearer tokens, but we’ll refer to them simply as “tokens” throughout this course for simplicity.