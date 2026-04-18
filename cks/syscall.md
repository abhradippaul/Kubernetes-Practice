which strace

strace ls

pidof cat

strace -p 4425

strace -c ls

## Tracee

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
