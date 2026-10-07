**If a Kubeconfig Is Leaked, Act Immediately**
  * Delete the certificate signing request (CSR)
  * Revoke or rotate the client certificate
  * Generate a new kubeconfig
  * `kubectl delete secret <sa-secret>`
  * `kubectl create token <sa-name>`
  * For OIDC users
    * Revoke the refresh token
    * Force new login
    * Disable their OIDC session
