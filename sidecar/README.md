# Sidecar Pod

## Create Nginx ConfigMap

```bash
# Create Nginx ConfigMap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app: nginx-deploy
  name: nginx-deploy-cm
data:
  nginx.conf: |
      events {}
      http {
          server {
              listen 80;
              server_name localhost;

              location / {
                root /usr/share/nginx/html;
                index index.html index.html;
              }

              location = /health {
                access_log off;
                default_type text/plain;
                add_header Content-Type text/plain;
                return 200 "ok";
            }
          }
      }
EOF
```

## Create Nginx Deployment

```bash
# Create Nginx Deployment
kubectl apply -f - <<EOF
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
      shareProcessNamespace: true
      volumes:
      - name: nginx-volume-cm
        configMap:
          name: nginx-deploy-cm
      containers:
      - image: alpine
        name: config-watcher
        command:
          - "sh"
          - "-c"
        args:
          - |
            apk add --no-cache inotify-tools
            while true; do
              inotifywait -e modify /tmp/nginx.conf
              pkill -HUP nginx
            done
        volumeMounts:
        - name: nginx-volume-cm
          mountPath: "/tmp"
          readOnly: true
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-volume-cm
          mountPath: "/etc/nginx"
          readOnly: true
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
EOF
```

## Create Nginx Service

```bash
# Create Nginx Service
kubectl apply -f - <<EOF
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
EOF
```

## Port Forward

```bash
# Port Forward
kubectl port-forward svc/nginx-deploy-service 80:80
```

## Verify the resources

```bash
# Verify the resources
kubectl get pod
kubectl get svc
kubectl get cm

# Verify container
kubectl logs nginx-deploy -c config-watcher
kubectl logs nginx-deploy -c nginx
```
