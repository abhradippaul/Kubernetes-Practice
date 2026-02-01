# Learn Autoscaling

## Prerequisite (Metrics Server, VPA)

```bash
# For autoscaling we need metrics server

# Add Helm repo
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add autoscalers https://kubernetes.github.io/autoscaler
helm repo update

# Setup metrics-server
helm upgrade --install metrics-server -n kube-system metrics-server/metrics-server \
--set "args[0]=--kubelet-insecure-tls"

# Verify the metrics server
kubectl top pods

# Setup VPA
helm upgrade --install vertical-pod-autoscaler -n kube-system autoscalers/vertical-pod-autoscaler \
-f helm-vpa-values.yaml
```

## Setup Deployment and Service

```bash
kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-deploy
  name: nginx-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-deploy
  template:
    metadata:
      labels:
        app: nginx-deploy
    spec:
      containers:
        - image: nginx
          name: nginx
          ports:
            - containerPort: 80
          resources:
            limits:
              cpu: 4m
              memory: 8Mi
            requests:
              cpu: 4m
              memory: 8Mi
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-deploy
  name: nginx-deploy-service
spec:
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app: nginx-deploy
  type: ClusterIP
---
EOF

# Verify setup
kubectl get pods
kubectl get svc
kubectl get endpoints
```

## Setup HPA Autoscaling

```bash
# Create HPA autoscale
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-deploy
spec:
  maxReplicas: 5
  metrics:
  - resource:
      name: cpu
      target:
        averageUtilization: 50
        type: Utilization
    type: Resource
  - resource:
      name: memory
      target:
        averageUtilization: 50
        type: Utilization
    type: Resource
  minReplicas: 2
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deploy
EOF

# Imperitive command
kubectl autoscale deploy nginx-deploy --cpu=50% --memory=50% --max=5 --min=2

# Check HPA
watch kubectl get hpa

# Load Test
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx-deploy-service; done"

# Delete hpa
kubectl delete hpa nginx-deploy
```

## Setup VPA Autoscaling

```bash
# Create VPA Autoscale
kubectl apply -f - <<EOF
apiVersion: "autoscaling.k8s.io/v1"
kind: VerticalPodAutoscaler
metadata:
  name: nginx-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: nginx-deploy
  updatePolicy:
    updateMode: Auto
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 10m
          memory: 20Mi
        maxAllowed:
          cpu: 20m #maximum vpa will be allocating this many cpus even if demand is higher.
          memory: 40Mi
        controlledResources: ["cpu", "memory"]
EOF

# Check VPA
watch kubectl get vpa

# Load Test
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx-deploy-service; done"
```
