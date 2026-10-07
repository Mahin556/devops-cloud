* OIDC Authentication (AUTH PROVIDER)
  * Used in enterprise clusters with:
    * Keycloak
    * Google Cloud
    * Azure AD
    * Okta
    * Auth0
  * This method uses OIDC tokens instead of certificates.

```bash
#Using Google Cloud OIDC on Kubernetes
#Configure API server
--oidc-issuer-url=https://accounts.google.com
--oidc-client-id=my-k8s-client
--oidc-username-claim=email
--oidc-groups-claim=groups

#User logs in through OIDC provider
#Example (Google):
gcloud auth login
gcloud container clusters get-credentials mycluster

#Or with Keycloak:
kubectl oidc-login setup
kubectl oidc-login get-token

#kubeconfig stores OIDC provider section
cat << EOF > ~/.kube/config
users:
- name: oidc-user
  user:
    auth-provider:
      name: oidc
      config:
        client-id: my-k8s-client
        client-secret: mysecret
        id-token: eyJhbGciOiJSUzI1N...
        refresh-token: 1//04cZ...
        idp-issuer-url: https://accounts.google.com
EOF
kubectl --user=oidc-user get pods
```