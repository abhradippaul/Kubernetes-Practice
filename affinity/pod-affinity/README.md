# Pod Affinity

## Create Pod

```bash
# Required Scheduling
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx-pod-affinity
    app: pod-affinity
  name: nginx-pod-affinity
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: run
                operator: In
                values:
                  - redis-pod
          topologyKey: kubernetes.io/hostname
  containers:
    - image: nginx
      name: nginx-pod-affinity
      ports:
        - containerPort: 80
EOF
```

## Delete Resource

```bash
# Delete resource
kubectl delete all -l app=pod-affinity
```
