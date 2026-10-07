### Best Practices / Tips
    - Prefer Secrets for sensitive info (DB passwords, API tokens).
    - Use envFrom for multiple keys to reduce YAML repetition.
    - Use optional: true for keys that may not exist.
    - Combine Downward API with ConfigMaps/Secrets for dynamic environment info.
    - Avoid hardcoding values that may change between environments; use ConfigMaps instead.
    - Remember: env vars are available to child processes, so your app can read them like normal OS env vars.

