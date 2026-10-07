* https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
* Monitoring and Troubleshooting (RBAC)
* Enable Audit Logging `/etc/kubernetes/audit-policy.yaml`
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log RBAC failures at detailed level
  - level: RequestResponse
    namespaces: [""]
    verbs: ["create", "update", "patch", "delete"]
    resources:
    - group: "rbac.authorization.k8s.io"
      resources: ["*"]

  # Log all denied requests
  - level: Request
    namespaces: [""]
    verbs: ["*"]
    resources: ["*"]
    omitStages:
    - RequestReceived
```
* API Server Flags `/etc/kubernetes/manifests/kube-apiserver.yaml`
```yaml
--audit-log-path=/var/log/kubernetes/audit.log
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100
```
* Troubleshooting Workflow
```bash
Permission Denied
        |
        v
Check Authentication (whoami)
        |
   +----+-----+
   |          |
Failed     Success
   |          |
Fix Auth   Check Role Exists
              |
        +-----+------+
        |            |
       No          Yes
        |            |
Create Role   Check RoleBinding
                    |
              +-----+------+
              |            |
             No          Yes
              |            |
      Create RoleBinding   Check Subject Match
                                |
                         +------+------+
                         |             |
                        No           Yes
                         |             |
                Fix Subject Name   Check API Group/Resources
```

---

* Kubernetes RBAC Maintenance Checklist
* Weekly RBAC Maintenance

  | Task                                          | Description                                                                                      |
  | --------------------------------------------- | ------------------------------------------------------------------------------------------------ |
  | **[ ] Review audit logs for RBAC failures**   | Look for `Forbidden` errors in API server logs to identify missing or misconfigured permissions. |
  | **[ ] Check for unused Roles & RoleBindings** | Identify RBAC objects that haven’t been used recently and mark for removal.                      |
  | **[ ] Validate Service Account usage**        | Ensure pods are using the *intended* service accounts, not `default`.                            |

* Monthly RBAC Maintenance

  | Task                                 | Description                                                                             |
  | ------------------------------------ | --------------------------------------------------------------------------------------- |
  | **[ ] Audit cluster-admin bindings** | Ensure *only platform admins* have `cluster-admin`; remove accidental bindings.         |
  | **[ ] Review wildcard permissions**  | Find any RBAC rules using `*` in verbs/resources and replace with explicit permissions. |
  | **[ ] Update RBAC documentation**    | Maintain annotations, purpose tags, and diagrams explaining each Role/ClusterRole.      |
  | **[ ] Test permission boundaries**   | Verify that users/apps have only the permissions they need (least privilege).           |
 
* Quarterly RBAC Maintenance

  | Task                                               | Description                                                                                     |
  | -------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
  | **[ ] Complete RBAC architecture review**          | Validate namespace boundaries, cluster roles, multi-namespace access, and operator permissions. |
  | **[ ] Update roles based on job function changes** | Remove access for ex-employees, team transfers, or deprecated services.                         |
  | **[ ] Perform security penetration testing**       | Attempt privilege escalation via RBAC to ensure boundaries are enforced.                        |
  | **[ ] Compliance verification**                    | Ensure policies meet SOC2, ISO, NIST, PCI, or internal governance rules.                        |
