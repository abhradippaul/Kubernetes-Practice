# Security Scanning and Policy Enforcement

This guide covers essential tools for static analysis and policy enforcement in Kubernetes clusters, focusing on `kubesec`, `kube-linter`, and `OPA`.

## Kubesec

### Description

**Kubesec** is an open-source security analysis tool for Kubernetes resources. It quantifies security risks for Kubernetes resources by scanning YAML manifests. It provides a security score and detailed remediation advice to help developers and operators harden their configurations.

### Features

- Scans Pods, Deployments, StatefulSets, and DaemonSets.
- Identifies overly permissive capabilities, missing security contexts, and insecure volume mounts.
- Provides a clear "Score" for each resource.

### Example

To scan a local manifest file:

```bash
kubesec scan pod.yaml
```

Output example:

```json
[
  {
    "object": "Pod/nginx.default",
    "valid": true,
    "score": 5,
    "advice": "Set securityContext.runAsNonRoot to true",
    "findings": [
      {
        "description": "Containers should be forbidden from gaining additional privileges",
        "severity": "critical"
      }
    ]
  }
]
```

## Kube-linter

### Description

**Kube-linter** is a static analysis tool that checks Kubernetes YAML files and Helm charts to ensure they follow best practices, with a strong focus on security and production readiness. It is configurable and can be integrated into CI/CD pipelines.

### Features

- Includes built-in checks for memory limits, latest tag usage, privileged mode, and other common risks.
- Supports custom checks and exclusions through configuration files.
- Works with raw YAML and Helm charts.

### Example

Lint a directory of manifests:

```bash
kube-linter lint /path/to/manifests
```

Lint with a specific configuration:

```bash
kube-linter lint pod.yaml --config .kube-linter.yaml
```

## OPA (Open Policy Agent)

### Description

**Open Policy Agent (OPA)** is a general-purpose policy engine that provides a unified way to enforce policies across the cloud-native stack. In Kubernetes, OPA is commonly deployed with **Gatekeeper** as an admission controller to validate or mutate requests based on custom policies written in **Rego**.

### Features

- Decouples policy decision-making from policy enforcement.
- Uses **Rego**, a declarative language designed for expressing complex policies.
- Can evaluate context-aware policies using cluster data such as Namespaces and Ingresses.

### Example Rego Policy

The following Rego policy denies any Pod that does not set `runAsNonRoot` to `true`:

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := sprintf("Container '%v' must set runAsNonRoot to true", [container.name])
}
```

### Example Usage

Test a policy locally with the OPA CLI:

```bash
opa eval --data policy.rego --input request.json "data.kubernetes.admission.deny"
```
