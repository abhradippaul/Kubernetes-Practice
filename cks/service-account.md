# Kubernetes Service Account Usage Guide

This guide demonstrates how to work with Kubernetes Service Accounts, including listing accounts, creating a test pod, verifying tokens, and using the token to access the Kubernetes API.

---

## 1. List Service Accounts in All Namespaces

To see all service accounts across namespaces:

```bash
kubectl get serviceaccount --all-namespaces
```

---

## 2. Create a Test App Pod

Deploy a simple NGINX pod for testing:

```bash
kubectl run app-pod --image=nginx
kubectl get pods
```

---

## 3. Verify Namespace Associated with Pod

Check which namespace the pod is running in:

```bash
kubectl describe pod app-pod
```

---

## 4. Verify Mounted Service Account Token in Pod

Access the pod and check the service account token:

```bash
kubectl exec -it app-pod -- bash
cd /var/run/secrets/kubernetes.io/serviceaccount/
ls
cat token
```

---

## 5. Connect to Kubernetes Cluster Using the Token

You can use the token to authenticate API requests:

```bash
token=$(cat token)
echo $token
```

From outside the pod, get cluster info:

```bash
kubectl cluster-info
```

Use curl to access the Kubernetes API (replace `control-plane-url-here` with your cluster's API endpoint):

```bash
curl -k -H "Authorization: Bearer $token" https://control-plane-url-here/api/v1
```

automountServiceAccountToken: false
kubectl exec -it pod-2 -- bash
automountServiceAccountToken: false

---

## 6. Authenticating with Service Account Token

You can authenticate to the Kubernetes API using the service account token from within a pod:

```bash
kubectl run pod-1 --image=nginx
kubectl exec -it pod-1 -- bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
echo $TOKEN
curl -k -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1"
curl -k -H "Authorization: Bearer $TOKEN" "https://kubernetes/api/v1/namespaces"
```

---

## 7. Opting Out of Auto-Mounting Service Account Tokens

Kubernetes automatically mounts service account tokens into pods. You can opt out at the service account or pod level.

### Approach 1: Opt Out at Service Account Level

Edit the service account and add the following snippet:

```bash
kubectl edit sa default
```

Add this under the service account spec:

```yaml
automountServiceAccountToken: false
```

**Verification:**

```bash
kubectl run pod-2 --image=nginx
kubectl exec -it pod-2 -- bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

---

### Approach 2: Opt Out at Pod Level

Create a pod manifest with `automountServiceAccountToken: false`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
spec:
  automountServiceAccountToken: false
  containers:
    - image: nginx
      name: demo-pod
```

Apply the manifest and verify:

```bash
kubectl apply -f pod-3.yaml
kubectl exec -it demo-pod -- bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

---

## 8. Clean Up Resources

Delete all pods created during these steps:

```bash
kubectl delete pods --all
```
