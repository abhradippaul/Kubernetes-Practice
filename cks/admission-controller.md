# Admission Controller Lab

This lab configures the Kubernetes API server to use an admission configuration file and enables the `ImagePolicyWebhook` admission plugin.

## Configure API Server (Tab 2)

Install `net-tools` and inspect listening ports:

```bash
apt install net-tools
netstat -ntlp
```

## Create Admission Configuration

Open the admission configuration file:

```bash
vim /etc/kubernetes/pki/admission-config.yaml
```

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: "/etc/kubernetes/pki/webhook-kubeconfig"
        allowTTL: 50
        denyTTL: 50
        retryBackoff: 500
        defaultAllow: false
```

## Create Webhook Kubeconfig

Open the webhook kubeconfig:

```bash
nano /etc/kubernetes/pki/webhook-kubeconfig
```

Replace the server IP address with your own IP.

```yaml
apiVersion: v1
kind: Config
clusters:
  - cluster:
      server: http://64.227.144.17:8080/validate
    name: webhook
contexts:
  - context:
      cluster: webhook
    name: webhook-context
current-context: webhook-context
```

## Enable Admission Controller Plugins

Open the API server manifest:

```bash
nano /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add or verify the following arguments:

```yaml
- --admission-control-config-file=/etc/kubernetes/pki/admission-config.yaml
- --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
```

Ensure the `ImagePolicyWebhook` plugin is enabled.

## Test the Setup

```bash
kubectl run nginx-pod --image=nginx
kubectl run redis-pod --image=redis
```
