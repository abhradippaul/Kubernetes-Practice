# Helm

```bash
# Add repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repo
helm repo update

# Repo list
helm repo list

# Install chart
helm install my-nginx bitnami/nginx --version 22.4.7
```

```bash
# Create helm chart
helm create my-app

helm install my-release ./my-app
```
