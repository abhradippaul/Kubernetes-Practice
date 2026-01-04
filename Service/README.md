# Understanding Service

## Basic Service Command
```bash
# Expose Pod 
kubectl expose pod nginx-pod --name=nginx-pod-service --port=80 --target-port=80 --type=ClusterIP

# Expose Deployment
kubectl expose deployment nginx-deploy --name=nginx-deploy-service --port=80 --target-port=80 --type=ClusterIP

# Edit service
kubectl edit svc nginx-service

# Delete Service
kubectl delete svc nginx-service
```

### Service Label and Annotation
```bash
# Add or Update label
kubectl label svc nginx-service env=stage --overwrite

# Remove label
kubectl label svc nginx-service env-

# Add or update Annotation
kubectl annotate svc nginx-service owner=team-b --overwrite

# Remove Annotation
kubectl annotate svc nginx-service owner-
```

### Basic Pod Checking Commands
```bash
# Get all service
kubectl get svc

# Watch all service
watch kubectl get svc

# Describe service
kubectl describe svc nginx-service
```