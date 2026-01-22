# Learn Autoscaling

## Prerequisite (Metrics Server)

```bash
# For autoscaling we need metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

#Change deployment settings in metrics server:

kubectl edit deploy -n kube-system metrics-server
Add args "- --kubelet-insecure-tls"

# Verify the metrics server
kubectl top pods
```

## Create Deployment

```bash
kubectl apply -f nginx-pod

# Create autoscale
kubectl apply -f hpa-autoscale.yaml

# Imperitive command
kubectl autoscale deploy nginx-deploy --cpu-percent=50 --memory-percent=50 --max=5 --min=2

# Check HPA
kubectl get hpa

# Load Test
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx-deploy-service; done"
```
