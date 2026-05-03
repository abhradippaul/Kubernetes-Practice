# Kubernetes Practice Project Overview

Kubernetes-Practice is a comprehensive repository dedicated to learning and practicing Kubernetes concepts. It serves as a personal laboratory for exploring various Kubernetes resources, architectural patterns, and security best practices, with a significant focus on the Certified Kubernetes Security Specialist (CKS) curriculum.

## Directory Overview

The project is structured into functional directories, each targeting a specific Kubernetes feature or resource type:

- **`cks/`**: Contains in-depth labs and documentation for CKS topics, including Admission Controllers, AppArmor, Auditing, ETCD security, Network Policies, Pod Security Standards, and Security Scanning.
- **Resource-Specific Directories**:
    - **`Pod/`, `Service/`, `Deployment/`, `statefulsets/`, `Daemonsets/`**: Manifests for core Kubernetes workloads and networking.
    - **`affinity/`, `taint-toleration/`**: Examples of node and pod scheduling constraints.
    - **`autoscaling/`**: Manifests for Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA).
    - **`configmap-secrets/`**: Examples of managing configuration and sensitive data.
    - **`storage/`, `storage-class/`**: Persistent Volume (PV) and Persistent Volume Claim (PVC) examples.
    - **`gateway-api/`**: Manifests for the modern Gateway API.
- **`helm/`**: A sample Helm chart (`my-app`) for practicing package management.
- **`multi-container/`**: Demonstrations of Init and Sidecar container patterns.
- **`health-check/`**: Liveness and Readiness probe configurations.

## Key Files

- **`cks/README.md`**: The primary index for security-related practice labs.
- **`README.md`**: A brief introduction to the project goals.
- **`Pod/nginx-pod.yaml`**: A foundational example of a Kubernetes Pod.
- **`Service/cluster-ip.yaml`**: A standard Service manifest for internal cluster communication.
- **`helm/my-app/Chart.yaml`**: Metadata for the sample Helm chart.

## Usage

### Applying Manifests
To practice deploying resources, apply the YAML files to a running Kubernetes cluster (e.g., Minikube, Kind, or a cloud provider) using:
```bash
kubectl apply -f <directory>/<filename>.yaml
```

### Security Labs
Follow the step-by-step instructions in the `cks/*.md` files to simulate real-world security configurations and hardening tasks. These often involve modifying cluster components like the `kube-apiserver` or `etcd`.

### Helm Practice
To deploy the sample Helm chart:
```bash
helm install my-release ./helm/my-app
```
