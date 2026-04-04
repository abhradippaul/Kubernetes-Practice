# Kubernetes API Server (kube-apiserver) Setup Guide

This document provides a step-by-step walkthrough for manually setting up the Kubernetes API Server. This is particularly relevant for the **Certified Kubernetes Security Specialist (CKS)** exam, which requires a deep understanding of control plane components.

<!-- NOTE: Ensure you have root privileges and necessary tools like wget and openssl installed. -->

## Step 1: Download Kubernetes Server Binaries

First, we download the official Kubernetes server binaries for the desired version.

```bash
# Create and navigate to the binaries directory
mkdir -p /root/binaries && cd /root/binaries

# Download the server tarball (using v1.32.1 as an example)
wget https://dl.k8s.io/v1.32.1/kubernetes-server-linux-amd64.tar.gz

# Extract the binaries
tar -xzvf kubernetes-server-linux-amd64.tar.gz

# Verify the binary locations
ls -lh /root/binaries/kubernetes/server/bin/

# Move the required binaries to a location in your PATH
cp /root/binaries/kubernetes/server/bin/kube-apiserver /usr/local/bin/
cp /root/binaries/kubernetes/server/bin/kubectl /usr/local/bin/
```

## Step 2: Generate Client Certificate for API Server

The API server needs to authenticate itself when communicating with `etcd`.

```bash
cd /root/certificates

# Generate the private key
openssl genrsa -out api-etcd.key 2048

# Create a Certificate Signing Request (CSR)
openssl req -new -key api-etcd.key -subj "/CN=kube-apiserver" -out api-etcd.csr

# Sign the CSR with the cluster CA
openssl x509 -req -in api-etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out api-etcd.crt -days 2000
```

## Step 3: Generate Service Account Certificates

Service accounts require a key pair for signing and verifying tokens.

```bash
cd /root/certificates

# Generate the private key for service accounts
openssl genrsa -out service-account.key 2048

# Create the CSR
openssl req -new -key service-account.key -subj "/CN=service-accounts" -out service-account.csr

# Sign the certificate
openssl x509 -req -in service-account.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out service-account.crt -days 100
```

## Step 4: Start kube-apiserver Manually

Run the API server with the necessary flags. Note the security-related flags used here.

```bash
/usr/local/bin/kube-apiserver \
  --advertise-address=159.65.147.161 \
  --etcd-cafile=/root/certificates/ca.crt \
  --etcd-certfile=/root/certificates/api-etcd.crt \
  --etcd-keyfile=/root/certificates/api-etcd.key \
  --etcd-servers=https://127.0.0.1:2379 \
  --service-cluster-ip-range=10.0.0.0/24 \
  --service-account-issuer=https://127.0.0.1:6443 \
  --service-account-key-file=/root/certificates/service-account.crt \
  --service-account-signing-key-file=/root/certificates/service-account.key
```

### Key Flags Explained:
- `--etcd-certfile/--etcd-keyfile`: Certificates used by the API server to authenticate with etcd.
- `--service-account-signing-key-file`: Used to sign Service Account tokens.
- `--service-account-key-file`: Used to verify Service Account tokens.
- `--service-account-issuer`: Identifier for the token issuer.

## Step 5: Verification

Check if the API server is listening and responding.

```bash
# Check if the process is listening on port 6443
netstat -ntlp | grep 6443

# Test the API endpoint directly
curl -k https://localhost:6443/version
```

## Step 6: Integrate with Systemd

For production or persistent environments, it's best to run the API server as a systemd service.

```bash
# Define the systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=165.22.212.16 \\
  --etcd-cafile=/root/certificates/ca.crt \\
  --etcd-certfile=/root/certificates/api-etcd.crt \\
  --etcd-keyfile=/root/certificates/api-etcd.key \\
  --etcd-servers=https://127.0.0.1:2379 \\
  --service-account-key-file=/root/certificates/service-account.crt \\
  --service-cluster-ip-range=10.0.0.0/24 \\
  --service-account-signing-key-file=/root/certificates/service-account.key \\
  --service-account-issuer=https://127.0.0.1:6443
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Step 7: Start and Enable the Service

```bash
# Reload systemd to pick up the new unit file
systemctl daemon-reload

# Start and enable the service
systemctl enable --now kube-apiserver

# Verify the status
systemctl status kube-apiserver
```
