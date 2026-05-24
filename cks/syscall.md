# Syscall Tracing and Seccomp

This guide covers basic syscall tracing with `strace`, runtime tracing with `tracee`, and seccomp profile enforcement for containers and Pods.

## Strace

Use `strace` to inspect Linux syscalls made by a process or command:

```bash
which strace
strace ls
pidof cat
strace -p 4425
strace -c ls
```

## Tracee

Run Tracee as a privileged container to trace host and container runtime events:

```bash
docker run --name tracee --rm --privileged --pid=host \
-v /lib/modules/:/lib/modules/:ro -v /usr/src:/usr/src:ro \
-v /tmp/tracee:/tmp/tracee aquasec/tracee:0.4.0 --trace comm=ls
```

```bash
docker run --name tracee --rm --privileged --pid=host \
-v /lib/modules/:/lib/modules/:ro -v /usr/src:/usr/src:ro \
-v /tmp/tracee:/tmp/tracee aquasec/tracee:0.4.0 --trace pid=new
```

## Seccomp

Check seccomp support and inspect seccomp status inside containers:

```bash
grep -i seccomp /boot/config-$(uname -r)
```

```bash
docker run -it --rm docker/whalesay /bin/sh

ps -ef
grep Seccomp /proc/1/status
```

```bash
docker run --rm r.j3ss.co/amicontained amicontained

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: amicontained
  labels:
    app: amicontained
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: amicontained
    image: r.j3ss.co/amicontained
    args:
    - amicontained
    securityContext:
      allowPrivilegeEscalation: false
EOF
```
