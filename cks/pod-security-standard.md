# Pod Security Standards Lab

This lab demonstrates how to apply Kubernetes Pod Security Standards at the namespace level and test `privileged`, `baseline`, and `restricted` enforcement behavior.

## Create 3 Namespaces

```bash
kubectl create ns privileged-ns
kubectl create ns baseline-ns
kubectl create ns restricted-ns
```

## Associate 3 Policy Levels for Namespaces

```bash
kubectl label namespace privileged-ns pod-security.kubernetes.io/enforce=privileged
kubectl label namespace baseline-ns pod-security.kubernetes.io/enforce=baseline
kubectl label namespace restricted-ns pod-security.kubernetes.io/enforce=restricted
```

## Testing

### 1. Privileged Pod

```bash
kubectl run privileged-pod --image=nginx --privileged -n privileged-ns
kubectl run privileged-pod --image=nginx --privileged -n baseline-ns
kubectl run privileged-pod --image=nginx --privileged -n restricted-ns
```

### 2. Default Config Pod

```bash
kubectl run normal-pod --image=nginx -n privileged-ns
kubectl run normal-pod --image=nginx -n baseline-ns
kubectl run normal-pod --image=nginx -n restricted-ns
```

### 3. Pod Manifest for Restricted Namespace

Create the manifest:

```bash
vim restricted-pod.yaml
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: restricted-ns
spec:
  containers:
    - name: secure-container
      image: busybox
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1001
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
```

Apply and verify:

```bash
kubectl create -f restricted-pod.yaml
kubectl get pods -n restricted-ns
kubectl delete -f restricted-pod.yaml
```

Modify the manifest file to include `runAsUser: 1001` in `securityContext`.

Recreate and validate:

```bash
kubectl create -f restricted-pod.yaml
kubectl get pods -n restricted-ns
kubectl exec -it restricted-pod -n restricted-ns -- sh
id
kubectl delete -f restricted-pod.yaml
```

## Create Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secured-ns
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/warn: restricted
```

## Testing

```bash
kubectl run nginx --image=nginx -n secured-ns
```

## Remove the Resources Created as Part of This Lab

```bash
kubectl delete pod nginx -n secured-ns
kubectl delete ns secured-ns
```

## Example 1. Mode Version

Create the manifest:

```bash
nano mode-version.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: secured-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.32
```

```bash
kubectl create -f mode-version.yaml
```

## Example 2. Workload Resources and Pod Templates

```bash
kubectl create deployment test-deployment --image=nginx --replicas=2 -n secured-ns
kubectl get deployments
kubectl get pods
```

## Example 3. Add Label to Default Namespace

```bash
kubectl run test-pod --image=nginx
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
```

## Example 4. Dry Run

```bash
kubectl label namespace default pod-security.kubernetes.io/enforce-
kubectl label --dry-run=server ns default pod-security.kubernetes.io/enforce=restricted
```

## Remove the Resources Created as Part of This Lab

```bash
kubectl delete -f mode-version.yaml
kubectl delete pod test-pod
```
