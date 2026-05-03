# CKS Exercises & Examples Index

This index lists all practical exercises, steps, and examples found in the `cks/` directory.

## 1. Cluster Setup & Hardening
### API Server & Kubelet (`kube-apiserver.md`, `kubelet.md`)
- Step 1: Download Kubernetes Server Binaries
- Step 2: Generate Client Certificate for API Server
- Step 3: Generate Service Account Certificates
- Step 4: Start kube-apiserver Manually
- Step 5: Verification
- Step 6: Integrate with Systemd
- Step 7: Start and Enable the Service
- Step 1: Access Worker Node Kubelet from Control Plane Node
- Step 2: Make a request to Kubelet API (Worker Node)
- Step 3: Modify the Kubelet Configuration (Worker Node)
- Step 4: Verify Kubelet API Access after Modification (Worker Node)
- Step 5: Download and Use kubeletctl (Worker Node)
- Step 6: Verify Kubelet Certificate

### ETCD Security (`etcd.md`, `README.md`)
- Step 1: Create a New Secret
- Step 2: Find the Secret in ETCD (Plain-Text)
- Step 3: Create Encryption Key
- Step 4: Create Encryption Config
- Step 5: Copy Configuration to Appropriate Path
- Step 6: Configure kube-apiserver
- Step 7: Create a New Secret (Post-Encryption)
- Step 8: Verify Encryption in ETCD
- ETCD TLS Encryption & mTLS Configuration

## 2. System Hardening
### AppArmor (`app-armor.md`)
- Check AppArmor Status
- Sample Script for Profile Generation
- Generate and Verify Profile
- Create a Sample Profile (Deny Write)
- Deploy a Pod with AppArmor Profile

### Seccomp & Syscalls (`syscall.md`)
- Tracing with `strace`
- Tracing with `tracee`
- Seccomp Profile Enforcement

### Read-Only Root Filesystems (`more-security.md`)
- Example 1: Read-Only Root Filesystem
- Example 2: Read-Only Root Filesystem With Writable `/tmp`
- Example 3: Nginx With Read-Only Root Filesystem

## 3. Minimize Microservice Vulnerabilities
### Pod Security Standards (`pod-security-standard.md`)
- Create 3 Namespaces (Privileged, Baseline, Restricted)
- Associate 3 Policy Levels for Namespaces
- Example 1: Mode Version
- Example 2: Workload Resources and Pod Templates
- Example 3: Add Label to Default Namespace
- Example 4: Dry Run

### Security Context & Capabilities (`security-context.md`)
- 1. Linux Capabilities Basics
- 2. Example: Insecure Pod (HostPath mount)
- 3. Example: Controlled Pod with Security Context (`runAsUser`, `runAsGroup`)
- 4. Example: `fsGroup` with `emptyDir`
- 6. Example: Add Linux Capabilities to a Pod
- 7. Example: Drop All and Add Back Specific Capabilities

## 4. Supply Chain Security
### SBOM & Vulnerability Scanning (`bom.md`)
- Install BOM & Trivy
- Generate SBOM for an image
- Scan an existing SBOM with Trivy

## 5. Monitoring, Logging, and Runtime Security
### Audit Logging (`audit.md`)
- Step 1: Create Sample Audit Policy File
- Step 2: Audit Configuration (API Server Flags)
- Step 3: Run Queries to Generate Logs
- Step 4: Verification (Grep logs)

## 6. Network Security
### Network Policies (`network-policy.md`)
- Example 1: Deny All Ingress and Egress
- Example 2: Allow All Ingress, Deny Egress
- Example 3: Isolate Pods by Label
- Example 4: Allow Ingress Only from App Pods
- Example 5: Allow Ingress from a Specific Namespace
- Example 6: Allow Egress to a Specific IP

### Cilium Advanced Policies (`cilium.md`)
- Example 1: Simple Deny Policy
- Example 2: Deny Policy for a Specific Pod
- Example 3: Allow Traffic from Curl Pod to Nginx Pod
- Example 4: Allow Egress Traffic from Curl Pod Only to Nginx Pod
- Entities Example: Cluster / World / All
- L4 Egress Policy Example
- DNS Policy Example
- Transparent Encryption (IPSec / WireGuard)

## 7. Identity and Access Management
### Service Accounts (`service-account.md`)
- 1. List Service Accounts
- 4. Verify Mounted Service Account Token
- 6. Authenticating with Service Account Token
- 7. Opting Out of Auto-Mounting Service Account Tokens

### API Priority and Fairness (`priority-and-fairness.md`)
- 1. API Priority and Fairness (APF) Configuration
- 2. Pod Priority and Preemption Example

## 8. Miscellaneous
### Admission Controllers (`admission-controller.md`)
- Create Admission Configuration
- Create Webhook Kubeconfig
- Enable Admission Controller Plugins (ImagePolicyWebhook)

### Ingress TLS (`ingress.md`)
- Step 3: Create Self-Signed Certificate
- Step 5: Create Kubernetes TLS Secret
- Step 6: Create Kubernetes Ingress with TLS

### Volumes (`volumes.md`)
- 2. Create a Pod with a Projected Volume (Secret + ConfigMap)
- 4. Mount a Service Account Token with a Projected Volume
