# CKS Practice Topics

This file provides a summary of the topics covered in the `cks/` directory.

- **ETCD Security**: ETCD Security Guidelines, Encryption at Rest, TLS configuration, and Systemd integration.
- **Certificates & TLS**: Certificate Authority (CA) setup, client/server certificates, mutual TLS (mTLS), and Docker TLS configuration.
- **Admission Controllers**: Configuration and testing of Admission Controller plugins like ImagePolicyWebhook.
- **AppArmor**: Profile generation, enforcement, and integration with Kubernetes pods.
- **Audit Logging**: Enabling and verifying Kubernetes API server audit logs.
- **Software Bill of Materials (SBOM)**: Managing SBOMs using `bom` and `trivy` tools.
- **Cilium Network Policy**: Advanced networking and security using Cilium, including L7 policies and transparent encryption (IPSec/WireGuard).
- **Ingress Security**: Configuring Nginx Ingress Controller with TLS termination and self-signed certificates.
- **Control Plane Security**: Manual setup and hardening of `kube-apiserver` and `kubelet`.
- **Runtime Security**: OCI runtimes (Containerd, RunC), gVisor isolation, and syscall tracing using `strace` and `tracee`.
- **Pod Security**:
    - Pod Security Standards (Privileged, Baseline, Restricted).
    - Security Contexts: `runAsUser`, `runAsGroup`, `fsGroup`, and Read-Only Root Filesystems.
    - Linux Capabilities: Adding and dropping capabilities.
    - Seccomp profiles.
- **Network Policies**: Standard Kubernetes NetworkPolicies for ingress/egress isolation.
- **Service Accounts**: Managing tokens, authentication, and opting out of automounting.
- **Volumes**: Projected volumes for Secrets, ConfigMaps, and ServiceAccount tokens.
- **Priority and Fairness**: API Priority and Fairness (APF) and Pod Priority/Preemption.
- **Security Scanning and Policy Enforcement**: Static analysis with `kubesec` and `kube-linter`, and dynamic policy enforcement with OPA/Gatekeeper.
