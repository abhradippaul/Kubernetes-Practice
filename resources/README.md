# Resource Management

## Create Limit Range

```bash
# Create Limit Range
kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: example-limitrange
spec:
  limits:
    - default: # this section defines default limits
        cpu: 500m
        memory: 500Mi
      defaultRequest: # this section defines default requests
        cpu: 500m
        memory: 500Mi
      max: # max and min define the limit range
        cpu: "1"
        memory: 1Gi
      min:
        cpu: 100m
        memory: 500Mi
      type: Container
EOF
```

## Verify Limit Range

```bash
# Get the limit range
kubectl get limitranges

# Describe the limit range
kubectl describe limitrange example-limitrange
```

## Create Resource Quota

```bash
# Create Resource Quota
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: example-resourcequota
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
EOF
```

## Verify Limit Range

```bash
# Get the limit range
kubectl get resourcequota

# Describe the limit range
kubectl describe resourcequota example-resourcequota
```
