# Kubernetes Ingress with TLS

This guide covers the steps to configure an Nginx Ingress Controller with TLS termination using a self-signed certificate.

## Step 1: Create Basic Pod and Service

Create a pod and expose it as a service:

```bash
kubectl run example-pod --image=nginx
kubectl expose pod example-pod --name example-service --port=80 --target-port=80
```

Verify the service:

```bash
kubectl get service
kubectl describe service example-service
```

## Step 2: Configure Nginx Ingress Controller

Deploy the Nginx Ingress Controller:

```bash
kubectl create -f https://raw.githubusercontent.com/zealvora/certified-kubernetes-security-specialist/refs/heads/main/domain-1-cluster-setup/nginx-controller.yaml
```

Verify the installation:

```bash
kubectl get pods -n ingress-nginx
kubectl get service -n ingress-nginx
```

## Step 3: Create Self-Signed Certificate

Generate a self-signed certificate for the domain `example.internal`:

```bash
mkdir -p /root/ingress
cd /root/ingress
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingress.key -out ingress.crt -subj "/CN=example.internal/O=security"
```

## Step 4: Verify the Default TLS Certificate

Use the NodePort associated with TLS to verify the default certificate:

```bash
curl -kv <IP>:NodePort
```

## Step 5: Create Kubernetes TLS Secret

Create a TLS secret in Kubernetes using the generated certificate and key:

```bash
kubectl create secret tls tls-certificate --key ingress.key --cert ingress.crt
kubectl get secret tls-certificate -o yaml
```

## Step 6: Create Kubernetes Ingress with TLS

Create an Ingress resource that uses the TLS secret:

```bash
kubectl create ingress demo-ingress --class=nginx --rule=example.internal/*=example-service:80,tls=tls-certificate
```

## Step 7: Make a Request to the Controller

Get the NodePort for the ingress-nginx service:

```bash
kubectl get service -n ingress-nginx
```

> [!IMPORTANT]
> Add an entry to `/etc/hosts` for `example.internal` mapping to your Node IP before running the command below.

```bash
curl -kv https://example.internal:31893
```

---

> [!CAUTION]
> **Do not delete the resources created for this practical if you are following a series.** They may be needed in the next session.

## Step 8: Cleanup (Optional)

If you need to delete the resources created:

```bash
kubectl delete pod nginx-pod
kubectl delete service example-service
kubectl delete ingress demo-ingress
kubectl delete secret tls-certificate

kubectl delete -f https://raw.githubusercontent.com/zealvora/certified-kubernetes-security-specialist/refs/heads/main/domain-1-cluster-setup/nginx-controller.yaml
```
