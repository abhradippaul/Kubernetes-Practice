# Understanding Gateway API

## Nginx Gateway Fabric CRD

```bash
#
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.4.1" | kubectl apply -f -
```

## Install Nginx Fabric

```bash
# Install Nginx Fabric
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
```