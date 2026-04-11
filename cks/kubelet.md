# Kubelet Security and API Interaction

This guide covers how to interact with the Kubelet API, modify its configuration for security purposes, and use specialized tools like `kubeletctl` for auditing.

## Step 1: Access Worker Node Kubelet from Control Plane Node

Navigate to the PKI directory and use the API server's client certificates to authenticate against the Kubelet API.

```bash
cd /etc/kubernetes/pki
# Replace the IP address with the actual Worker Node IP
curl -k --cert apiserver-kubelet-client.crt --key apiserver-kubelet-client.key https://localhost:10250/pods
```

## Step 2: Make a request to Kubelet API (Worker Node)

Check the Kubelet API locally on the worker node.

```bash
apt install net-tools
netstat -ntlp
curl -k -X GET https://localhost:10250/pods
```

## Step 3: Modify the Kubelet Configuration (Worker Node)

Backup and modify the Kubelet configuration to adjust authentication and authorization settings.

```bash
cd /var/lib/kubelet
cp config.yaml config.yaml.bak
```

**Configuration Changes:**

- Set `anonymous: enabled: false`
- Set `authorization: mode: AlwaysAllow` (Note: Use with caution, usually `Webhook` is preferred for security)

```bash
systemctl restart kubelet
systemctl status kubelet
```

## Step 4: Verify Kubelet API Access after Modification (Worker Node)

```bash
curl -k -X GET https://localhost:10250/pods
```

## Step 5: Download and Use kubeletctl (Worker Node)

[kubeletctl](https://github.com/cyberark/kubeletctl) is a Swiss army knife for Kubelet API discovery and exploitation.

```bash
wget https://github.com/cyberark/kubeletctl/releases/download/v1.13/kubeletctl_linux_amd64 && \
chmod a+x ./kubeletctl_linux_amd64 && \
mv ./kubeletctl_linux_amd64 /usr/local/bin/kubeletctl

# List pods
kubeletctl pods -i

# Run command in all pods
kubeletctl run "whoami" --all-pods -i
```

## Step 6: Verify Kubelet Certificate

Inspect the certificate used by the Kubelet.

```bash
openssl s_client -showcerts -connect 127.0.0.1:10250 2>/dev/null | openssl x509 -inform pem -noout -text
```
