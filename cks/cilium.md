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

Create 2 Pods for Testing
kubectl run nginx --image=nginx

kubectl run curl --image=alpine/curl -- sleep 36000
Entities - Cluster
nano entities-cluster.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "restrict-egress-to-cluster"
spec:
endpointSelector: {}
egress: - toEntities: - "cluster"
kubectl create -f entities-cluster.yaml
Test the Setup

kubectl get pods -o wide

kubectl exec -it curl-pod -- sh

curl <NGINX-POD-IP>

ping google.com

curl google.com
kubectl delete -f entities-cluster.yaml
Entities - World
nano entities-world.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "restrict-egress-to-cluster"
spec:
endpointSelector: {}
egress: - toEntities: - "world"
kubectl create -f entities-world.yaml
Test the Setup

kubectl get pods -o wide

kubectl exec -it curl-pod -- sh

curl <NGINX-POD-IP>
curl google.com
ping google.com
kubectl delete -f entities-world.yaml
Entities - All
nano entities-all.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "allow-all-egress"
spec:
endpointSelector: {}
egress: - toEntities: - "all"
kubectl create -f entities-all.yaml
Test the Setup

kubectl get pods -o wide

kubectl exec -it curl-pod -- sh

curl <NGINX-POD-IP>

curl google.com

ping google.com
kubectl delete -f entities-all.yaml
Delete the Resources Created for this Lab
kubectl delelte pods --all

Create 2 Pods for Testing
kubectl run nginx --image=nginx

kubectl run curl --image=alpine/curl -- sleep 36000
Create Cilium Network Policy
nano cnp-l4.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: allow-external-80
spec:
endpointSelector:
matchLabels:
run: curl
egress: - toPorts: - ports: - port: "80"
protocol: TCP
Test the Setup

kubectl get pods -o wide

kubectl exec -it curl-pod -- sh

curl <NGINX-POD-IP>

ping google.com

curl google.com
Delete the Resources Created for this Lab
kubectl delete -f cnp-l4.yaml

kubectl delelte pods --all

Create Pod for Testing
kubectl run curl --image=alpine/curl -- sleep 36000
DNS
nano allow-dns.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "allow-dns-kplabs"
spec:
endpointSelector: {}
egress:

- toPorts: - ports: - port: "53"
  rules:
  dns: - matchName: "kplabs.in"
  kubectl create -f allow-dns.yaml
  Testing
  nslookup google.com

nslookup kplabs.in
Delete the Setup
kubectl delete -f allow-dns.yaml kubectl delete pod curl

Create 3 Pods for Testing
kubectl run nginx --image=nginx --labels=app=server

kubectl run random-pod --labels=app=random-pod --image=alpine/curl -- sleep 36000

kubectl run backend-pod --image=alpine/curl -- sleep 36000
1 - Create ingressDeny Policy
nano ingressDeny.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "deny-ingress"
spec:
endpointSelector:
matchLabels:
app: server
ingress:

- fromEntities:
  - all
    ingressDeny:
- fromEndpoints: - matchLabels:
  app: random-pod
  kubectl create -f ingressDeny.yaml
  Verification
  kubectl get pods -o wide

kubectl exec -it backend-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>

kubectl exec -it random-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>
kubectl delete -f ingressDeny.yaml
2 - Create egressDeny Policy
nano egressDeny.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
name: "deny-egress"
spec:
endpointSelector:
matchLabels:
app: random-pod
egress:

- toEntities:
  - all
    egressDeny:
- toEndpoints: - matchLabels:
  app: server
  kubectl create -f egressDeny.yaml
  Verification
  kubectl get pods -o wide

kubectl exec -it random-pod -- sh
curl <NGINX-POD-IP>
ping <NGINX-POD-IP>

curl google.com
ping google.com
Delete the Created Resources
kubectl delete -f egressDeny.yaml

kubectl delete pod nginx random-pod backend-pod

Generate and Import PSK
kubectl create -n kube-system secret generic cilium-ipsec-keys \
 --from-literal=keys="3+ rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"

kubectl -n kube-system get secrets cilium-ipsec-keys
Enable Transparent Encryption in Cilium (IPSec)
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=ipsec

cilium status

cilium config view | grep enable-ipsec

kubectl get nodes
Testing the Setup
Launch 2 Pods in different worker node (Terminal Tab 1)
nano curl-pod.yaml
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
  kubectl create -f curl-pod.yaml
  nano nginx-pod.yaml
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
  kubectl create -f nginx-pod.yaml
  Run a bash shell in one of the Cilium pods (Terminal Tab 2)
  kubectl -n kube-system exec -ti ds/cilium -- bash
  Install tcpdump and check if traffic is encrypted
  apt-get update
  apt-get -y install tcpdump
  tcpdump -n -i cilium_vxlan esp
  In Terminal Tab 1
  kubectl get pods -o wide

kubectl exec -it curl -- sh

curl <NGINX-POD-IP>
Delete the Kind Cluster
kind delete cluster

Enable Transparent Encryption in Cilium (WireGuard)
cilium install --version 1.17.1 --set encryption.enabled=true --set encryption.type=wireguard

cilium status

cilium config view | grep enable-wireguard
Testing the Setup
Launch 2 Pods in different worker node (Terminal Tab 1)
nano curl-pod.yaml
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
  kubectl create -f curl-pod.yaml
  nano nginx-pod.yaml
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
  kubectl create -f nginx-pod.yaml
  Run a bash shell in one of the Cilium pods (Terminal Tab 2)
  kubectl -n kube-system exec -ti ds/cilium -- bash
  Install tcpdump and check if traffic is encrypted
  apt-get update
  apt-get -y install tcpdump
  tcpdump -n -i cilium_wg0 -nn -vv
  In Terminal Tab 1
  kubectl get pods -o wide

kubectl exec -it curl-pod -- sh

curl <NGINX-POD-IP>
