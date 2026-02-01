# Health Checks

## Liveness Probes

```bash
# Create Pod to check liveness prob
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: nginx-liveness
  name: nginx-liveness
spec:
  containers:
    - name: liveness
      image: nginx
      ports:
        - containerPorts: 80
      livenessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
      resources:
        limits:
          cpu: 10m
          memory: 20Mi
        requests:
          cpu: 10m
          memory: 20Mi
EOF
```

## Readiiness Probes

```bash
# Create Pod to check readiness prob
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: nginx-readiness
  name: nginx-readiness
spec:
  containers:
    - name: readiness
      image: nginx
      ports:
        - containerPorts: 80
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
      resources:
        limits:
          cpu: 10m
          memory: 20Mi
        requests:
          cpu: 10m
          memory: 20Mi
EOF
```
