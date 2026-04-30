# OCI Runtime & Kubernetes Security

Guide for working with Containerd, RunC, and gVisor in Kubernetes.

## Install Containerd

Configure kernel modules and sysctl:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
```

Install and configure `containerd`:

```bash
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
```

## Create Container with Containerd

Using `ctr` CLI:

```bash
ctr image pull docker.io/library/nginx:latest
ctr image ls
ctr container create docker.io/library/nginx:latest nginx
ctr container list
```

## Using RunC

Manually creating a container with `runc`:

```bash
# Prepare rootfs
mkdir /root/nginx-rootfs
ctr snapshot mounts nginx-rootfs/ nginx | bash

# Generate OCI spec
cd /root
runc spec

# Note: Modify config.json to point to nginx-rootfs

# Run container
runc run mycontainer
```

## Kubernetes Cluster Setup (Kubeadm)

### Step 1: Installation
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet=1.20.1-00 kubeadm=1.20.1-00 kubectl=1.20.1-00
```

### Step 2: Initialize
```bash
kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Step 3: Install Network Addon (flannel)
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### Step 4: Remove Taints
```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## Minikube with gVisor Setup

### Step 1: Configure Docker
```bash
sudo apt update && apt -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io
```

### Step 2: Install Minikube
```bash
wget https://github.com/kubernetes/minikube/releases/download/v1.37.0/minikube-linux-amd64
mv minikube-linux-amd64 minikube
chmod +x minikube
sudo mv ./minikube /usr/local/bin/minikube
```

### Step 3: Start Minikube & Enable gVisor
```bash
minikube start --container-runtime=containerd --docker-opt containerd=/var/run/containerd/containerd.sock
minikube addons enable gvisor
```

## Explore gVisor RuntimeClass

Create a `RuntimeClass` for gVisor:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

Deploy a Pod using gVisor:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - image: nginx
    name: nginx
```

Verify the isolation:

```bash
kubectl exec -it nginx-gvisor -- uname -r
# Compare with host:
uname -r
```
