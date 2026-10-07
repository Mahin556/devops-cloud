- `kubectl auth whoami`

- `kubectl auth can-i create pods`

- `kubectl auth can-i create deployments`

- `kubectl auth can-i delete secrets`

- `kubectl auth can-i create pods --as=jane`

- `kubectl auth can-i create deployments --as=jane`

- `kubectl auth can-i delete secrets --as=jane` #Does not required user entry inn kubeconfig file

- `kubectl auth can-i create pods --user=jane`

- `kubectl auth can-i create deployments --user=jane`#Required user entry inn kubeconfig file

- `kubectl auth can-i delete secrets --user=jane`

- `kubectl auth can-i create pods --as=nobody` #If user does not exist it simply say no instead of giving an error

```bash
--user  = use a real user from your kubeconfig
          (must exist under "users:")

--as    = impersonate any user (even if not in kubeconfig)
          requires RBAC: impersonate/users, groups, serviceaccounts

Examples:
kubectl --user=developer get pods
# Uses kubeconfig's developer credentials

kubectl --as=mahinder get pods
# Pretend to be user "mahinder"

kubectl --as=system:serviceaccount:dev:sa1 get pods
# Pretend to be service account dev/sa1

TL;DR:
--user = switch kubeconfig user
--as   = impersonate a user or service account
```

- `kubectl auth can-i create pods --as=poweruser`

- `kubectl auth can-i create deployments --as=poweruser`

- `kubectl auth can-i delete secrets --as=poweruser`

- `kubectl auth can-i create pods --as=poweruser --as-group=example:masters`

- `kubectl auth can-i create deployments --as=poweruser --as-group=example:masters`

- `kubectl auth can-i delete secrets --as=poweruser --as-group=example:masters`

```bash
# --as = check permissions as a specific user
kubectl auth can-i create pods --as=poweruser

# --as-group = also include the group for the authorization check
# Useful when the permission comes from a GroupRole/RoleBinding.
kubectl auth can-i create pods \
  --as=poweruser \
  --as-group=example:masters

# Check if poweruser (as a member of example:masters)
# can create deployments
kubectl auth can-i create deployments \
  --as=poweruser \
  --as-group=example:masters

# Check if poweruser (as a member of example:masters)
# can delete secrets
kubectl auth can-i delete secrets \
  --as=poweruser \
  --as-group=example:masters
```
```bash
k auth can-i -h
k auth can-i create deployments --as smoke -n applications
```
```bash
kubectl auth can-i create deployments --as system:serviceaccount:ns1:pipeline -n ns1

kubectl auth can-i create deployments --as system:serviceaccount:ns1:pipeline -n ns2
```
```bash
k auth can-i delete deployments --as smoke -n applications
k auth can-i delete pods --as smoke -n applications
k auth can-i delete sts --as smoke -n applications
k auth can-i delete secrets --as smoke -n applications
k auth can-i list deployments --as smoke -n applications
k auth can-i list secrets --as smoke -n application
k auth can-i get secrets --as smoke -n applications
k auth can-i list pods --as smoke -n default
```