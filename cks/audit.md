# Kubernetes Audit Logging

This guide demonstrates how to enable and verify Kubernetes audit logging. Audit logs are essential for tracking access and changes to your cluster, helping with security and compliance.

## Step 1 - Create Sample Audit Policy File

First, create an audit policy file that defines what events should be logged by the Kubernetes API server. The example below logs metadata for all requests.

```bash
# Create or edit the audit policy file
vim /etc/kubernetes/audit-policy.yaml
```

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata # Log metadata for all requests
```

---

## Step 2 – Audit Configuration

Next, configure the API server to use the audit policy and specify where to store the audit logs. Add the following flags to your kube-apiserver manifest or systemd service file:

Add the following flags:

```bash
# Example kube-apiserver flags for audit logging
--audit-policy-file=/etc/kubernetes/audit-policy.yaml
--audit-log-path=/var/log/kubernetes/audit/audit.log
--audit-log-maxage=30         # Days to retain old audit log files
--audit-log-maxbackup=10      # Maximum number of audit log files to retain
--audit-log-maxsize=100       # Maximum size in MB of the audit log file before rotation
```

```yaml
# Example volume mounts for static pod manifest
volumeMounts:
  - mountPath: /etc/kubernetes/audit-policy.yaml
    name: audit
    readOnly: true
  - mountPath: /var/log/kubernetes/audit/
    name: audit-log
    readOnly: false

volumes:
  - name: audit
    hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
```

> **Note:** After updating the configuration, restart the kube-apiserver for changes to take effect.

---

## Step 3 – Run Some Queries Using Bob User

Now, perform some actions in the cluster to generate audit log entries. For example, run a command as a user (e.g., Bob) to access secrets:

```bash
# Run a command to generate audit log entries
kubectl get secret
```

---

## Step 4 – Verification

Finally, check the audit log to verify that your actions were recorded. Search for relevant entries (e.g., access to secrets) in the audit log file:

```bash
cd /var/log/kubernetes/audit/
# Search for 'secret' access events in the audit log
grep -i secret audit.log
```

---

> **Tip:** Regularly review audit logs to monitor for suspicious activity and ensure compliance with security policies.
