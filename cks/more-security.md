# Kubernetes Security Context: Read-Only Root Filesystem

This guide demonstrates how to harden Kubernetes Pods by enabling
`readOnlyRootFilesystem` in the container `securityContext`.

It includes three practical examples:

- A BusyBox Pod with a read-only root filesystem
- A BusyBox Pod with a read-only root filesystem and writable `/tmp`
- An Nginx Pod example showing common runtime issues with read-only filesystems

## Why This Matters

Setting `readOnlyRootFilesystem: true` prevents a container from writing to its
root filesystem. This reduces the impact of container compromise because an
attacker cannot easily modify binaries, drop files, or persist changes inside the
container image filesystem.

When an application needs a writable path, mount a dedicated volume such as
`emptyDir` only where write access is required.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured for the cluster
- Basic knowledge of Pods, volumes, and security contexts

## Example 1: Read-Only Root Filesystem

Create a manifest file:

```bash
nano security-context-ro.yaml
```

Add the following Pod definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
    - name: demo
      image: busybox:1.37
      command: ["sleep", "1h"]
      securityContext:
        readOnlyRootFilesystem: true
```

Apply the manifest:

```bash
kubectl create -f security-context-ro.yaml
```

### Test Write Access

Open a shell inside the Pod:

```bash
kubectl exec -it readonly-pod -- sh
```

Try writing to the root filesystem:

```bash
touch test.txt
```

This should fail because the root filesystem is read-only.

Try writing to `/tmp`:

```bash
cd /tmp
touch test.txt
```

Depending on the container image and runtime configuration, this may also fail
unless `/tmp` is backed by a writable volume.

## Example 2: Read-Only Root Filesystem With Writable `/tmp`

Create a manifest file:

```bash
nano security-context-ro-empty-dir.yaml
```

Add the following Pod definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod-emptydir
spec:
  containers:
    - name: my-container
      image: busybox:1.37
      command: ["sleep", "1h"]
      securityContext:
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp-storage
          mountPath: /tmp
  volumes:
    - name: tmp-storage
      emptyDir: {}
```

Apply the manifest:

```bash
kubectl create -f security-context-ro-empty-dir.yaml
```

### Test Write Access

Open a shell inside the Pod:

```bash
kubectl exec -it readonly-pod-emptydir -- sh
```

Try writing to the root filesystem:

```bash
touch test.txt
```

This should fail because the container root filesystem is read-only.

Now try writing to `/tmp`:

```bash
cd /tmp
touch test.txt
```

This should succeed because `/tmp` is mounted from a writable `emptyDir` volume.

## Example 3: Nginx With Read-Only Root Filesystem

Create or update the manifest file:

```bash
nano security-context-nginx-ro.yaml
```

Add the following Pod definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-ro
spec:
  containers:
    - name: my-container
      image: nginx
      securityContext:
        readOnlyRootFilesystem: true
```

Apply the manifest:

```bash
kubectl create -f security-context-nginx-ro.yaml
```

Check the Pod logs:

```bash
kubectl logs nginx-ro
```

Nginx commonly needs writable paths for cache, PID files, and temporary runtime
data. With a read-only root filesystem, it may fail unless the required writable
paths are mounted as volumes.

## Key Takeaways

- Use `readOnlyRootFilesystem: true` to reduce container filesystem write access.
- Mount writable volumes only for paths that genuinely need writes.
- `emptyDir` is useful for temporary writable storage during the Pod lifetime.
- Some applications, such as Nginx, need additional writable runtime directories.
- Always test application startup and logs after enabling read-only filesystem
  controls.

## Cleanup

Remove the test Pods when finished:

```bash
kubectl delete pod readonly-pod readonly-pod-emptydir nginx-ro
```
