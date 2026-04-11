# Network Policy

This document collects basic Kubernetes `NetworkPolicy` examples and simple test commands you can run while practicing for CKS.

## Base Network Policy

Base policy manifest file:

`base-netpol.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: base-network-policy
```

## Example 1: Deny All Ingress and Egress

This example applies a policy to all pods and denies both ingress and egress traffic by defining both policy types with no allowed rules.

`example-1.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-1
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Create Pod for Testing

```bash
kubectl run test-pod --image=alpine/curl -- sleep 36000
kubectl get pods
kubectl exec -it test-pod -- sh
ping google.com
curl google.com
```

### Apply and Verify

```bash
kubectl create -f example-1.yaml
kubectl get netpol
kubectl describe netpol example-1
```

### Test the Setup

```bash
kubectl exec -it test-pod -- sh
ping google.com
```

### Cleanup

```bash
kubectl delete -f example-1.yaml
```

## Example 2: Allow All Ingress, Deny Egress

This example allows all incoming traffic to selected pods while still restricting outgoing traffic.

`example-2.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-2
spec:
  podSelector: {}
  ingress:
    - {}
  policyTypes:
    - Ingress
    - Egress
```

### Apply and Verify

```bash
kubectl create -f example-2.yaml
kubectl describe netpol example-2
```

### Test the Setup

```bash
kubectl run random-pod --image=alpine/curl -- sleep 36000
kubectl get pods -o wide
kubectl exec -it random-pod -- sh
ping <IP-OF-TEST-POD>

kubectl create ns testing
kubectl run random-pod -n testing --image=alpine/curl -- sleep 36000
kubectl get pods -n testing
kubectl exec -it random-pod -n testing -- sh
ping <IP-OF-TEST-POD>
```

## Example 3: Isolate Pods by Label

This example targets only pods labeled `role=suspicious` and blocks both ingress and egress for them.

`example-3.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-3
spec:
  podSelector:
    matchLabels:
      role: suspicious
  policyTypes:
    - Ingress
    - Egress
```

### Apply and Verify

```bash
kubectl create -f example-3.yaml
```

### Test the Setup

```bash
kubectl run suspicious-pod --image=alpine/curl -- sleep 36000
kubectl label pod suspicious-pod role=suspicious
kubectl exec -it suspicious-pod -- sh
ping google.com
```

## Example 4: Allow Ingress Only from App Pods

This example allows traffic to database pods only from pods labeled `role=app`.

`example-4.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-4
spec:
  podSelector:
    matchLabels:
      role: database
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: app
  policyTypes:
    - Ingress
```

### Apply and Verify

```bash
kubectl create -f example-4.yaml
```

### Test the Setup

```bash
kubectl run app-pod --image=alpine/curl -- sleep 36000
kubectl run database-pod --image=alpine/curl -- sleep 36000
kubectl get pods -o wide

kubectl exec -it test-pod -- sh
ping <DB-POD-IP>

kubectl label pod app-pod role=app
kubectl exec -it app-pod -- sh
ping <DB-POD-IP>
```

### Cleanup

```bash
kubectl delete -f example-4.yaml
```

## Example 5: Allow Ingress from a Specific Namespace

This example allows traffic to all pods in the `production` namespace only from pods in the `security` namespace.

`example-5.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-5
  namespace: production
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: security
  policyTypes:
    - Ingress
```

### Apply and Prepare Namespaces

```bash
kubectl create ns production
kubectl create ns security
kubectl get ns --show-labels
kubectl create -f example-5.yaml
```

### Test the Setup

```bash
kubectl run prod-pod -n production --image=alpine/curl -- sleep 36000
kubectl run security-pod -n security --image=alpine/curl -- sleep 36000

kubectl exec -it security-pod -n security -- sh
ping <PROD-POD-IP>
```

### Cleanup

```bash
kubectl delete -f example-5.yaml
```

## Example 6: Allow Egress to a Specific IP

This example allows outbound traffic only to `8.8.8.8/32` from pods in the `production` namespace.

`example-6.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: example-6
  namespace: production
spec:
  podSelector: {}
  egress:
    - to:
        - ipBlock:
            cidr: 8.8.8.8/32
  policyTypes:
    - Egress
```

### Apply and Verify

```bash
kubectl create -f example-6.yaml
kubectl exec -it prod-pod -n production -- sh
ping 8.8.8.8
```

### Cleanup

```bash
kubectl delete -f example-6.yaml
```

## Remove Created Resources

Use these commands to remove the pods and namespaces created during practice.

```bash
kubectl delete pods --all
kubectl delete pod security-pod -n security
kubectl delete pod prod-pod -n production
kubectl delete pods --all -n testing

kubectl delete ns testing
kubectl delete ns production
kubectl delete ns security
```
