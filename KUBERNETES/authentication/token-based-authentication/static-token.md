#### Static Token File

* Similar to static password files, but uses a token instead of a username-password combo.

* Format (CSV):

  ```
  token,username,uid,"group1,group2"
  ```

  Example:

  ```
  abcd1234token,varun,uid123,"devs"
  ```

* Supplied to the API server using:

  ```
  --token-auth-file=/etc/kubernetes/tokens.csv
  ```

* Again, restart the API server for it to take effect.

* Example `curl` request:

  ```bash
  curl -H "Authorization: Bearer abcd1234token" https://<cluster-endpoint>/api
  ```

* ❌ Also not recommended for production — static, plain text, no rotation mechanism.
