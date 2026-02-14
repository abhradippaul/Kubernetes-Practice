# Understanding Ingress

## Create Service A

```bash
# Create Service A
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-a
data:
  path-a.html: |
    "/path-a.html" on service-a
  path-b.html: |
    "/path-b.html" on service-a
  index.html: |
    "/" on service-a  
  404.html: |
    service-a 404 page
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-a-nginx.conf
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-a
  labels:
    app: service-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service-a
  template:
    metadata:
      labels:
        app: service-a
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/
        - name: config
          mountPath: /etc/nginx/
      volumes:
      - name: html
        configMap:
          name: service-a
      - name: config
        configMap:
          name: service-a-nginx.conf
---
apiVersion: v1
kind: Service
metadata:
  name: service-a
spec:
  selector:
    app: service-a
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
EOF
```

## Create Service B

```bash
# Create Service B
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-b
data:
  path-a.html: |
    "/path-a.html" on service-b
  path-b.html: |
    "/path-b.html" on service-b
  index.html: |
    "/" on service-b  
  404.html: |
    service-b 404 page
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-b-nginx.conf
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-b
  labels:
    app: service-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service-b
  template:
    metadata:
      labels:
        app: service-b
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html/
        - name: config
          mountPath: /etc/nginx/
      volumes:
      - name: html
        configMap:
          name: service-b
      - name: config
        configMap:
          name: service-b-nginx.conf
---
apiVersion: v1
kind: Service
metadata:
  name: service-b
spec:
  selector:
    app: service-b
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
EOF
```

## Create Domain based Ingress

```bash
# Create Domain based Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-domain
spec:
  ingressClassName: nginx
  rules:
  - host: public.service-a.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-a
            port:
              number: 80

  - host: public.service-b.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```

## Create Routing based Ingress

```bash
# Create Routing based Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path
  annotations:
    nginx.org/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: public.my-services.com
    http:
      paths:
      - path: /path-a
        pathType: Prefix
        backend:
          service:
            name: service-a
            port:
              number: 80

      - path: /path-b
        pathType: Prefix
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```

## Create Advanced Routing based Ingress

```bash
# Create Routing based Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-path
  annotations:
    nginx.org/path-regex: "case_sensitive"
    nginx.org/rewrites: |
      serviceName=service-a rewrite=/path-a/(.*) /$1 break;
      serviceName=service-b rewrite=/path-b/(.*) /$1 break;
spec:
  ingressClassName: nginx
  rules:
  - host: public.my-services.com
    http:
      paths:
      - path: /path-a/(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-a
            port:
              number: 80

      - path: /path-b/(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-b
            port:
              number: 80
EOF
```

## Create Nginx Ingress Controller

```bash
# Add repo using helm
helm repo add nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress
helm repo update

# Helm release install
helm upgrade --install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress -n ingress-nginx --create-namespace
```

## Check ingress

```bash
# Curl ingress
curl --resolve public.service-a.com:30214:127.0.0.1 http://public.service-a.com:30214
curl --resolve public.service-b.com:30214:127.0.0.1 http://public.service-b.com:30214
curl --resolve public.my-services.com:30799:127.0.0.1 http://public.my-services.com:30799
```