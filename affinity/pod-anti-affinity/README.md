# Pod Anti Affinity

## Create Pod

```bash
# Required Scheduling
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx-pod-anti-affinity
    app: pod-anti-affinity
  name: nginx-pod-anti-affinity
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: run
                operator: In
                values:
                  - nginx-pod
          topologyKey: kubernetes.io/hostname
  containers:
    - image: nginx
      name: nginx-pod-anti-affinity
      ports:
        - containerPort: 80
EOF
```

## Delete Resource

```bash
# Delete resource
kubectl delete all -l app=pod-anti-affinity
```
