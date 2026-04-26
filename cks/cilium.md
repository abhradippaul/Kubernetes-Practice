# Cilium Network Policy Practice

This guide shows how to remove an existing Kubernetes CNI, install Cilium, create test pods, and practice basic `CiliumNetworkPolicy` examples for CKS preparation.

## Prerequisites

- A running Kubernetes cluster
- `kubectl` configured for the cluster
- `sudo` access on the node where CNI files and iptables rules are cleaned up
- Internet access to download the Cilium CLI

## Remove Existing Networking

Delete old Canal or Calico components if they exist.

```bash
kubectl delete daemonset canal -n kube-system --ignore-not-found
kubectl delete daemonset calico-node -n kube-system --ignore-not-found
kubectl delete deployment calico-kube-controllers -n kube-system --ignore-not-found
```

Remove old CNI configuration files.

```bash
sudo rm -rf /etc/cni/net.d/*
```

Flush existing iptables rules.

```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X
```

## Install Cilium

Download and install the Cilium CLI.

```bash
CLI_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --fail --remote-name-all \
  https://github.com/cilium/cilium-cli/releases/download/v0.16.24/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

Install Cilium in the cluster.

```bash
cilium install
cilium status
kubectl get nodes
```

## Create Test Pods

Create an Nginx pod and a Curl pod for connectivity testing.

```bash
kubectl run nginx --image=nginx
kubectl run curl --image=alpine/curl -- sleep 36000
```

Verify pod placement and IP addresses.

```bash
kubectl get pods -o wide
```

Test connectivity from the Curl pod to the Nginx pod.

```bash
kubectl exec -it curl -- sh
curl <NGINX-IP>
```

## Example 1: Simple Deny Policy

This policy denies all ingress and egress traffic for all selected endpoints.

Create `deny.yaml`.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-traffic"
spec:
  endpointSelector: {}
  ingress:
    - {}
  egress:
    - {}
```

Apply and verify the policy.

```bash
kubectl create -f deny.yaml
kubectl get ciliumnetworkpolicies
```

### Test the Simple Deny Policy

Traffic from the Curl pod should be blocked.

```bash
kubectl exec -it curl -- sh
curl <NGINX-IP>
ping google.com
```

Delete the policy.

```bash
kubectl delete -f deny.yaml
```

## Example 2: Deny Policy for a Specific Pod

This policy denies all ingress and egress traffic only for pods with the label `run=curl`.

Create `deny-pod.yaml`.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "deny-traffic"
spec:
  endpointSelector:
    matchLabels:
      run: curl
  ingress:
    - {}
  egress:
    - {}
```

Apply and verify the policy.

```bash
kubectl create -f deny-pod.yaml
kubectl get cnp
```

### Test the Specific Pod Deny Policy

The Curl pod should be blocked, while the Nginx pod should not be selected by this policy.

```bash
kubectl exec -it curl -- sh
ping google.com

kubectl exec -it nginx -- sh
curl google.com
```

Delete the policy.

```bash
kubectl delete -f deny-pod.yaml
```

## Example 3: Allow Traffic from Curl Pod to Nginx Pod

This policy allows ingress traffic to the Nginx pod only from pods with the label `run=curl`.

Create `allow-curl-pod.yaml`.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-curl-nginx
spec:
  endpointSelector:
    matchLabels:
      run: nginx
  ingress:
    - fromEndpoints:
        - matchLabels:
            run: curl
```

Apply the policy.

```bash
kubectl create -f allow-curl-pod.yaml
```

### Test the Allow Curl to Nginx Policy

The Curl pod should be able to reach Nginx.

```bash
kubectl exec -it curl -- sh
curl <NGINX-POD-IP>
```

Create another pod and verify that it cannot reach Nginx.

```bash
kubectl run random-pod --image=alpine/curl -- sleep 36000
kubectl exec -it random-pod -- sh
curl <NGINX-POD-IP>
```

Delete the policy.

```bash
kubectl delete -f allow-curl-pod.yaml
```

## Example 4: Allow Egress Traffic from Curl Pod Only to Nginx Pod

This policy allows egress traffic from the Curl pod only to the Nginx pod.

Create `egress-to-nginx.yaml`.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-egress-curl-to-nginx
spec:
  endpointSelector:
    matchLabels:
      run: curl
  egress:
    - toEndpoints:
        - matchLabels:
            run: nginx
```

Apply the policy.

```bash
kubectl create -f egress-to-nginx.yaml
```

### Test the Egress Policy

The Curl pod should reach the Nginx pod but should not reach external IPs.

```bash
kubectl exec -it curl -- sh
curl <NGINX-POD-IP>
ping 8.8.8.8
```

Delete the policy.

```bash
kubectl delete -f egress-to-nginx.yaml
```

## Clean Up

Delete all pods created during this practice.

```bash
kubectl delete pods --all
```

kubectl run curl --image=alpine/curl -- sleep 36000
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
ping google.com
curl google.com
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
curl google.com
ping google.com

---

## Entities Example: Cluster

### Create 2 Pods for Testing

```bash
kubectl run nginx --image=nginx
kubectl run curl --image=alpine/curl -- sleep 36000
```

### Create a CiliumNetworkPolicy to restrict egress to the cluster

Create a file named `entities-cluster.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: restrict-egress-to-cluster
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - cluster
```

Apply the policy:

```bash
kubectl create -f entities-cluster.yaml
```

#### Test the Setup

```bash
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
Entities - All
curl google.com
```

Delete the policy:

```bash
kubectl delete -f entities-cluster.yaml
```

---

## Entities Example: World

Create a file named `entities-world.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: restrict-egress-to-world
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - world
```

Apply the policy:

```bash
kubectl create -f entities-world.yaml
```

#### Test the Setup

```bash
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
curl google.com
ping google.com
```

Delete the policy:

```bash
kubectl delete -f entities-world.yaml
```

kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
curl google.com
ping google.com
kubectl run curl --image=alpine/curl -- sleep 36000
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
ping google.com
curl google.com
kubectl delelte pods --all

---

## Entities Example: All

Create a file named `entities-all.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-all-egress
spec:
  endpointSelector: {}
  egress:
    - toEntities:
        - all
```

Apply the policy:

```bash
kubectl create -f entities-all.yaml
```

#### Test the Setup

```bash
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
curl google.com
ping google.com
```

Delete the policy:

```bash
kubectl delete -f entities-all.yaml
```

---

## L4 Egress Policy Example

### Create 2 Pods for Testing

```bash
kubectl run nginx --image=nginx
kubectl run curl --image=alpine/curl -- sleep 36000
```

### Create a CiliumNetworkPolicy to allow egress only to port 80

Create a file named `cnp-l4.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-80
spec:
  endpointSelector:
    matchLabels:
      run: curl
  egress:
    - toPorts:
        - ports:
            - port: "80"
              protocol: TCP
```

Apply the policy:

```bash
kubectl create -f cnp-l4.yaml
```

#### Test the Setup

```bash
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
ping google.com
curl google.com
```

Delete the policy:

```bash
kubectl delete -f cnp-l4.yaml
```

---

## DNS Policy Example

### Create Pod for Testing

```bash
kubectl run curl --image=alpine/curl -- sleep 36000
```

### Create a CiliumNetworkPolicy to allow DNS to a specific domain

Create a file named `allow-dns.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-dns-kplabs
spec:
  endpointSelector: {}
  egress:
    - toPorts:
        - ports:
            - port: "53"
          rules:
            dns:
              - matchName: "kplabs.in"
```

Apply the policy:

```bash
kubectl create -f allow-dns.yaml
```

#### Testing

```bash
nslookup google.com
nslookup kplabs.in
```

Delete the setup:

```bash
kubectl delete -f allow-dns.yaml
kubectl delete pod curl
```

kubectl run random-pod --labels=app=random-pod --image=alpine/curl -- sleep 36000
kubectl run backend-pod --image=alpine/curl -- sleep 36000
kubectl exec -it backend-pod -- sh
kubectl exec -it random-pod -- sh
kubectl delete -f ingressDeny.yaml
egress:
kubectl exec -it random-pod -- sh
curl google.com
kubectl delete pod nginx random-pod backend-pod
kubectl -n kube-system get secrets cilium-ipsec-keys
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=ipsec
cilium status
cilium config view | grep enable-ipsec
kubectl get nodes
nano curl-pod.yaml
kubectl exec -it curl -- sh
curl <NGINX-POD-IP>
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=wireguard
cilium status
cilium config view | grep enable-wireguard
nano curl-pod.yaml

---

## Advanced Policy: Ingress and Egress Deny

### Create 3 Pods for Testing

```bash
kubectl run nginx --image=nginx --labels=app=server
kubectl run random-pod --labels=app=random-pod --image=alpine/curl -- sleep 36000
kubectl run backend-pod --image=alpine/curl -- sleep 36000
```

### 1. Create ingressDeny Policy

Create a file named `ingressDeny.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: deny-ingress
spec:
  endpointSelector:
    matchLabels:
      app: server
  ingress:
    - fromEntities:
        - all
      ingressDeny: {}
    - fromEndpoints:
        - matchLabels:
            app: random-pod
```

Apply the policy:

```bash
kubectl create -f ingressDeny.yaml
```

#### Verification

```bash
kubectl get pods -o wide
kubectl exec -it backend-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>
kubectl exec -it random-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>
```

Delete the policy:

```bash
kubectl delete -f ingressDeny.yaml
```

### 2. Create egressDeny Policy

Create a file named `egressDeny.yaml` with the following content:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: deny-egress
spec:
  endpointSelector:
    matchLabels:
      app: random-pod
  egress:
    - toEntities:
        - all
      egressDeny: {}
    - toEndpoints:
        - matchLabels:
            app: server
```

Apply the policy:

```bash
kubectl create -f egressDeny.yaml
```

#### Verification

```bash
kubectl get pods -o wide
kubectl exec -it random-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>
curl google.com
ping google.com
```

Delete the policy and pods:

```bash
kubectl delete -f egressDeny.yaml
kubectl delete pod nginx random-pod backend-pod
```

---

## Transparent Encryption with Cilium

### Generate and Import PSK (IPSec)

```bash
kubectl create -n kube-system secret generic cilium-ipsec-keys \
  --from-literal=keys="3+ rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"
kubectl -n kube-system get secrets cilium-ipsec-keys
```

### Enable Transparent Encryption in Cilium (IPSec)

```bash
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=ipsec
cilium status
cilium config view | grep enable-ipsec
kubectl get nodes
```

### Test IPSec Encryption

Create two pods on different worker nodes:

**curl-pod.yaml**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: curl
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker
  containers:
    - name: busybox
      image: alpine/curl
      command: ["sleep", "36000"]
```

**nginx-pod.yaml**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker2
  containers:
    - name: nginx
      image: nginx
```

```bash
kubectl create -f curl-pod.yaml
kubectl create -f nginx-pod.yaml
```

Run a bash shell in a Cilium pod and check for encrypted traffic:

```bash
kubectl -n kube-system exec -ti ds/cilium -- bash
apt-get update && apt-get -y install tcpdump
tcpdump -n -i cilium_vxlan esp
```

In another terminal:

```bash
kubectl get pods -o wide
kubectl exec -it curl -- sh
curl <NGINX-POD-IP>
```

Delete the Kind cluster:

```bash
kind delete cluster
```

---

## Transparent Encryption with WireGuard

### Enable Transparent Encryption in Cilium (WireGuard)

```bash
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=wireguard
cilium status
cilium config view | grep enable-wireguard
```

### Test WireGuard Encryption

Create two pods on different worker nodes (as above), then:

```bash
kubectl -n kube-system exec -ti ds/cilium -- bash
apt-get update && apt-get -y install tcpdump
tcpdump -n -i cilium_wg0 -nn -vv
```

In another terminal:

```bash
kubectl get pods -o wide
kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>
```

kubectl exec -it curl-pod -- sh
curl <NGINX-POD-IP>

---

## Example Pod YAML for WireGuard Test

**nginx-pod.yaml**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker2
  containers:
    - name: nginx
      image: nginx
```

Apply the pod manifest:

```bash
kubectl create -f nginx-pod.yaml
```

---

You have now completed all Cilium network policy and encryption practice steps for CKS preparation!
