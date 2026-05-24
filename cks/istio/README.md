# Istio Kind Lab

This guide creates a Kind cluster for Istio, installs the demo profile, enables sidecar injection, and deploys the Bookinfo sample with Gateway API resources.

## Create the Cluster and Install Istio

```bash
kind create cluster --name "istio-cluster" --config ./istio-cluster.yaml
docker update --restart=no $(docker ps -a -q --filter label=io.x-k8s.kind.cluster="istio-cluster")
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled
```

## Install Gateway API and Bookinfo

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
{ kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.5.1" | kubectl apply -f -; }
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/gateway-api/bookinfo-gateway.yaml
kubectl annotate gateway bookinfo-gateway networking.istio.io/service-type=NodePort --nodePort=30000 --namespace=default
```
