# Understanding Deployment And Replicaset

## Deployment Creation and Config with Imperetive Commands
```bash
# Create Deployment Resource
kubectl create deployment nginx-deploy --image=nginx --replicas=2 --port=80

# Set Request and Limit 
kubectl set resources deployment nginx-deploy --limits=cpu=10m,memory=20Mi --requests=cpu=10m,memory=20Mi

# Update Replica of Deployment
kubectl set image deployments nginx-deploy nginx=nginx:stable-alpine3.23

# Scale Replica of Deployment
kubectl scale deployments nginx-deploy --replicas=3

# Edit Deployment
kubectl edit deployment nginx-deploy

# Delete Deployment
kubectl delete deploy nginx-deploy
```

## Deployment Label and Annotation
```bash
# Create or Update the label in Deployment
kubectl label deployment nginx-deploy env=prod --overwrite

# Remove Deployment label
kubectl label deployment nginx-deploy env-

# Create or Update the annotate
kubectl annotate deployment nginx-deploy owner=team-b --overwrite

# Create or Update the annotate
kubectl annotate deployment nginx-deploy owner-
```

## Deployment Rollout
```bash
# Rollout Restart Deployment
kubectl rollout restart deployment nginx-deploy

# Rollout Status
kubectl rollout status deployment nginx-deploy

# Pause Rollout
kubectl rollout pause deployment nginx-deploy

# Resume Rollout
kubectl rollout resume deployment nginx-deploy

# Rollout Change Cause Naming
kubectl annotate deployment nginx-deploy kubernetes.io/change-cause="image updated to alpine"

# Rollout history
kubectl rollout history deployment nginx-deploy

# Rollout Undo Previous version
kubectl rollout undo deployment nginx-deploy

# Rollout to a specific version
kubectl rollout undo deployment nginx-deploy --to-revision=2
```

### Basic Deployment Checking Commands
```bash
# Watch the Pods
watch kubectl get pods

# Describe Deployment
kubectl describe deploy nginx-deploy

# Get Deployment Yaml
kubectl get deploy nginx-deploy -o yaml

# Get Deployment Json
kubectl get deploy nginx-deploy -o json

# Get Deployment with Label
kubectl get deploy --show-labels

# Get Deployment with Details
kubectl get deploy -o wide
```