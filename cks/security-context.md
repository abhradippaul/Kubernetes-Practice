# Kubernetes Security Context for CKS

This note covers important CKS topics around Linux capabilities and Kubernetes `securityContext`, including user/group settings, `fsGroup`, and container capability management.

## What You Will Practice

- Inspect Linux capabilities on the host
- Understand why unrestricted Pods are risky
- Use `runAsUser`, `runAsGroup`, and `fsGroup`
- Verify file ownership behavior inside containers
- Add and drop Linux capabilities in Kubernetes Pods

## 1. Linux Capabilities Basics

Linux capabilities break root privileges into smaller, more controlled permission sets.

### Check the capabilities manual

```bash
man capabilities
```

### Verify the capability on the `ping` binary

```bash
which ping
getcap /usr/bin/ping
```

### Test `ping` with a non-root user

```bash
useradd -m -s /bin/bash demouser
su - demouser
ping google.com
```

### Remove and re-add capability for `ping`

Run these as root:

```bash
setcap -r /usr/bin/ping
getcap /usr/bin/ping

setcap cap_net_raw=ep /usr/bin/ping
getcap /usr/bin/ping
```

## 2. Example: Insecure Pod

This Pod mounts the host root filesystem directly, which is highly risky and should be avoided in real environments.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
spec:
  containers:
    - name: demo-container
      image: busybox:latest
      command: ["sleep", "36000"]
      volumeMounts:
        - name: host-root
          mountPath: /host
  volumes:
    - name: host-root
      hostPath:
        path: /
```

Apply and inspect:

```bash
kubectl apply -f pod.yaml
kubectl get pods
kubectl exec -it insecure-pod -- sh
id
cd /host
ls
cd /boot
ls -l
```

Cleanup:

```bash
kubectl delete pod insecure-pod
```

## 3. Example: Controlled Pod with Security Context

This Pod sets user and group ownership at the Pod level.

Create `pod-controlled.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: controlled-pod
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 2000
    fsGroup: 3000
  containers:
    - name: demo-container
      image: busybox:latest
      command: ["sleep", "36000"]
      volumeMounts:
        - name: host-root
          mountPath: /host
  volumes:
    - name: host-root
      hostPath:
        path: /
```

Apply and inspect:

```bash
kubectl apply -f pod-controlled.yaml
kubectl get pods
kubectl exec -it controlled-pod -- sh
id
cd /host
ls
cd /boot
cd grub
vi grub.cfg
```

### Verify UID, GID, and fsGroup behavior

```bash
cd /host/tmp
touch test.txt
ls -l
```

## 4. Example: `fsGroup` with `emptyDir`

This example is useful for observing how `fsGroup` affects writable shared volumes.

Create `pod-fs.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fsgroup-pod
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 2000
    fsGroup: 3000
  volumes:
    - name: host-root
      emptyDir: {}
  containers:
    - name: demo-container
      image: busybox:latest
      command: ["sleep", "36000"]
      volumeMounts:
        - name: host-root
          mountPath: /host
```

Apply and verify:

```bash
kubectl apply -f pod-fs.yaml
kubectl exec -it fsgroup-pod -- sh
id
cd /host
touch test.txt
ls -l
```

Cleanup all practice Pods:

```bash
kubectl delete pods --all
```

## 5. Inspect Capabilities in a Normal Pod

Start a basic Pod:

```bash
kubectl run normal-pod --image=busybox -- sleep 36000
kubectl exec -it normal-pod -- sh
```

Check effective capabilities:

```bash
cat /proc/1/status
capsh --decode=<capabilities-here>
```

## 6. Example: Add Linux Capabilities to a Pod

Create `capability-1.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod-1
spec:
  containers:
    - name: demo
      image: busybox
      command: ["sleep", "36000"]
      securityContext:
        capabilities:
          add: ["NET_ADMIN", "SYS_TIME"]
```

Apply and inspect:

```bash
kubectl apply -f capability-1.yaml
kubectl exec -it capabilities-pod-1 -- sh
cat /proc/1/status
capsh --decode=<capabilities-here>
```

## 7. Example: Drop All and Add Back Specific Capabilities

This is the safer pattern because it starts from zero privileges and grants only what is needed.

Create `capability-2.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-pod-2
spec:
  containers:
    - name: demo-2
      image: busybox
      command: ["sleep", "36000"]
      securityContext:
        capabilities:
          add: ["NET_ADMIN", "SYS_TIME"]
          drop: ["ALL"]
```

Apply and inspect:

```bash
kubectl apply -f capability-2.yaml
kubectl exec -it capabilities-pod-2 -- sh
cat /proc/1/status
capsh --decode=<capabilities-here>
```

## Quick Summary

- `securityContext` helps control container privileges and identity
- `runAsUser` and `runAsGroup` define the process user and group
- `fsGroup` affects ownership/permissions for supported mounted volumes
- `hostPath` can expose the node filesystem and should be used very carefully
- Dropping all capabilities first is safer than allowing default privileges
