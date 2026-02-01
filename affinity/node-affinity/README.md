# Node Affinity

## Node Label

```bash
# Add label to node
kubectl label node node01 disktype=hdd
kubectl label node controlplane disktype=ssd

# Add non value label
kubectl label node node01 gpu=

# Remove label from node
kubectl label node node01 disktype-
```

## Create Pod

```bash
# Required Scheduling
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: redis-pod
    app: node-affinity
  name: redis-pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: disktype
                operator: In
                values:
                  - ssd
  containers:
    - image: redis
      name: redis-pod
      ports:
        - containerPort: 6379
EOF

# Preferred Scheduling
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx-pod
    app: node-affinity
  name: nginx-pod
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          preference:
            matchExpressions:
              - key: disktype
                operator: In
                values:
                  - hdd
  containers:
    - image: nginx
      name: nginx-pod
      ports:
        - containerPort: 80
EOF
```

## Delete resources

```bash
# Delete all resource
kubectl delete all -l app=affinity
```
