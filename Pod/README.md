# Understanding Pod

## Pod Creation and Config with Imperetive Commands
```bash
# Create Pod With Resource
kubectl run nginx-pod --image=nginx --port=80

# Create or Update the label in pod
kubectl label pod nginx-pod env=prod --overwrite

# Remove pod label
kubectl label pod nginx-pod env-

# Delete Pod
kubectl delete pod nginx-pod
```

### Basic Pod Checking Commands
```bash
# Describe Pod
kubectl describe pod nginx-pod

# Get Pod Yaml
kubectl get pods nginx-pod -o yaml

# Get Pod Json
kubectl get pods nginx-pod -o json

# Get Pods with Label
kubectl get pods --show-labels

# Get Pods with Details
kubectl get pods -o wide

# Get Pods with selector
kubectl get pods --selector tier=frontend
```