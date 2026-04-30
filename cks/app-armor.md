# AppArmor in Kubernetes

This guide covers the basic commands and procedures for using AppArmor to secure Kubernetes pods.

## Check AppArmor Status

Check if AppArmor is active on the host:

```bash
systemctl status apparmor
# OR
aa-status
```

## Sample Script for Profile Generation

Create a sample script to test profile generation:

```bash
mkdir /root/apparmor
cd /root/apparmor

cat <<EOF > app.sh
#!/bin/bash
touch /tmp/file.txt
echo "New File created"
rm -f /tmp/file.txt
echo "New file removed"
EOF

chmod +x app.sh
```

## Install AppArmor Utilities

Install the necessary tools for managing AppArmor profiles:

```bash
apt install apparmor-utils -y
```

## Generate and Verify Profile

Generate a new profile for the sample script:

```bash
aa-genprof ./app.sh
# Follow prompts, then run ./app.sh from another tab
```

Verify the generated profile:

```bash
cat /etc/apparmor.d/root.apparmor.app.sh
aa-status
```

## Disable a Profile

To disable a profile:

```bash
ln -s /etc/apparmor.d/root.apparmor.app.sh /etc/apparmor.d/disable/
apparmor_parser -R /etc/apparmor.d/root.apparmor.app.sh
```

## Create a Sample Profile (Deny Write)

Create a profile that denies write operations:

```bash
apparmor_parser -q <<EOF
#include <tunables/global>

profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>
  file,
  # Deny all file writes.
  deny /** w,
}
EOF
```

Verify the profile is loaded:

```bash
aa-status
```

## Deploy a Pod with AppArmor Profile

Create a Pod that uses the `k8s-apparmor-example-deny-write` profile:

```bash
cd /root
cat <<EOF > hello-armor.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-apparmor
spec:
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-apparmor-example-deny-write
  containers:
  - name: hello
    image: busybox
    command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
EOF

kubectl apply -f hello-armor.yaml
```

## Verification

Test the AppArmor profile by attempting to create a file inside the container:

```bash
kubectl exec -it hello-apparmor -- sh
# Inside the container:
touch /tmp/file.txt
# This should be denied.
```
