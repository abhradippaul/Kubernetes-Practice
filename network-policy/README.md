# Network Policy

## Service A

```bash
# Create Namespace service-a
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: service-a
  labels:
    app: service-a
EOF

# Create Service A html file configmap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-a
  labels:
    app: service-a
  namespace: service-a
data:
  index.html: |
    "/" on service-a
EOF

# Create Service Nginx Conf configmap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-a-nginx.conf
  labels:
    app: service-a
  namespace: service-a
data:
  nginx.conf: |
    user  nginx;
    worker_processes  1;
    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;
    events {
        worker_connections  1024;
    }

    http {
        sendfile       on;
        server {
          listen       80;
          server_name  localhost;

          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
          }

          error_page 404 /404.html;
          error_page   500 502 503 504  /50x.html;
          location = /50x.html {
              root   /usr/share/nginx/html;
          }
        }
    }
EOF

# Create Service A Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: service-a
  name: service-a
  namespace: service-a
spec:
  volumes:
  - name: html
    configMap:
      name: service-a
  - name: config
    configMap:
      name: service-a-nginx.conf
  containers:
  - image: nginx
    name: nginx-pod
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
    - name: config
      mountPath: /etc/nginx/
EOF

# Create Service A service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-a
  labels:
    app: service-a
  namespace: service-a
spec:
  selector:
    app: service-a
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF
```

## Service B

```bash
# Create Namespace service-b
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: service-b
  labels:
    app: service-b
EOF

# Create Service B html file configmap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-b
  labels:
    app: service-b
  namespace: service-b
data:
  index.html: |
    "/" on service-b
EOF

# Create Service Nginx Conf configmap
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-b-nginx.conf
  labels:
    app: service-b
  namespace: service-b
data:
  nginx.conf: |
    user  nginx;
    worker_processes  1;
    error_log  /var/log/nginx/error.log warn;
    pid        /var/run/nginx.pid;
    events {
        worker_connections  1024;
    }

    http {
        sendfile       on;
        server {
          listen       80;
          server_name  localhost;

          location / {
              root   /usr/share/nginx/html;
              index  index.html index.htm;
          }

          error_page 404 /404.html;
          error_page   500 502 503 504  /50x.html;
          location = /50x.html {
              root   /usr/share/nginx/html;
          }
        }
    }
EOF

# Create Service B Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: service-b
  labels:
    app: service-b
  namespace: service-b
spec:
  volumes:
  - name: html
    configMap:
      name: service-b
  - name: config
    configMap:
      name: service-b-nginx.conf
  containers:
  - image: nginx
    name: nginx-pod
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html/
    - name: config
      mountPath: /etc/nginx/
EOF

# Create Service B service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: service-b
  labels:
    app: service-b
  namespace: service-b
spec:
  selector:
    app: service-b
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF
```

```bash
# Verify the other service
kubectl exec -it service-a -n service-a -- curl service-b.service-b.svc.cluster.local

# Verify the other service
kubectl exec -it service-b -n service-b -- curl service-a.service-a.svc.cluster.local
```

# Create client

```bash
# Create Busybox client
kubectl run busybox-pod --image=busybox --labels=app=busybox-pod -n service-a -- sleep 3600
kubectl run busybox-pod --image=busybox --labels=app=busybox-pod -- sleep 3600

# Exec to client
kubectl exec -it busybox-pod -n service-a -- wget -q -O- service-b.service-b.svc.cluster.local
kubectl exec -it busybox-pod -n service-a -- wget -q -O- service-a.service-a.svc.cluster.local
kubectl exec -it busybox-pod -- wget -q -O- service-b.service-b.svc.cluster.local
kubectl exec -it busybox-pod -- wget -q -O- service-a.service-a.svc.cluster.local
```

## Create Network Policy for Service B

```bash
# Create Network Policy for Service B
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-b-network-policy
  namespace: service-b
spec:
  podSelector:
    matchLabels:
      app: service-b
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: service-a
      podSelector:
        matchLabels:
          app: busybox-pod
    ports:
    - protocol: TCP
      port: 80
EOF
```