# Understanding Gateway API

## Install Gateway API CRDs

```bash
# Install Gateway API CRDs
# kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml

# Verify the crds
kubectl get crds | grep gateway

# Verify the api resources
kubectl api-resources --api-group=gateway.networking.k8s.io
```

## Install Nginx Gateway Fabric CRD

```bash
# Install Nginx Gateway Fabric CRD using kustomize
# kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.4.2" | kubectl apply -f -
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.4.2/deploy/crds.yaml

# Verify the Nginx Gateway Fabric CRD
kubectl get crds | grep -iE "gateway.nginx"
```

## Install Nginx Fabric

```bash
# Install Nginx Fabric using helm
# helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
# kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.4.2/deploy/default/deploy.yaml

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --namespace nginx-gateway \
  --create-namespace \
  --version 2.4.0 \
  --wait

# Verify the Nginx Fabric
kubectl -n nginx-gateway get all
```

## Create Gateway Class

```bash
# Create Gateway Class
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx-gateway-class
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
  parametersRef:
    group: gateway.nginx.org
    kind: NginxProxy
    name: ngf-proxy-config
    namespace: nginx-gateway
EOF

# Verify Gateway Class
kubectl get gatewayclass
kubectl describe gatewayclass nginx-gateway-class
```

## Create the Gateway Object

```bash
# Create the namespace
kubectl create ns webserver

# Create the Gateway Object
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: webserver
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same #or All or Selector
EOF

# Verify the Gateway Object
kubectl get gateway -n webserver
kubectl -n webserver describe gateway web-gateway
```

## Create the application

```bash
# Create the nginx deployment and service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: webserver
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx-container
          image: nginx:1.21
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: webserver
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

# Create the apache deployment and service
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache
  namespace: webserver
spec:
  replicas: 2
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
        - name: apache-container
          image: httpd:2.4
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: apache-service
  namespace: webserver
spec:
  selector:
    app: apache
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

# Verify the application resources
kubectl get all -n webserver
```

## Create http route

```bash
# Create domain base http route
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-httproute-domainbase
  namespace: webserver
spec:
  parentRefs:
    - name: web-gateway
      sectionName: http
      kind: Gateway
  hostnames:
    - "www.nginx.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: nginx-service
          port: 80
          weight: 1

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: apache-httproute-domainbase
  namespace: webserver
spec:
  parentRefs:
    - name: web-gateway
      sectionName: http
      kind: Gateway
  hostnames:
    - "www.apache.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: apache-service
          port: 80
          weight: 1
EOF

# Create path base http route
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: webserver-httproute-pathbase
  namespace: webserver
spec:
  parentRefs:
    - name: web-gateway
      sectionName: http
      kind: Gateway
  hostnames:
    - "www.path.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /nginx
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              replace: /
      backendRefs:
        - name: nginx-service
          port: 80
          weight: 1
    - matches:
        - path:
            type: PathPrefix
            value: /apache
      filters:
        - type: RequestRedirect
          requestRedirect:
            path:
              replace: /
      backendRefs:
        - name: apache-service
          port: 80
          weight: 1
EOF

# Verify http route
kubectl get httproute -n webserver
```

## Accessing Domain-Based Route

To access the domain-based route:

- For nginx service:
  ```bash
  curl --resolve www.nginx.com:<Gateway_Port>:<Gateway_IP> http://www.nginx.com/
  ```
- For apache service:
  ```bash
  curl --resolve www.apache.com:<Gateway_Port>:<Gateway_IP> http://www.apache.com/
  ```

Replace `<Gateway_IP>` with the IP address of your gateway (e.g., NodePort or LoadBalancer IP) and `<Gateway_Port>` with the port (usually 80).

## Accessing Path-Based Route

To access the path-based route:

- For nginx service (rewrites /nginx to /):
  ```bash
  curl http://<Gateway_IP>:<Gateway_Port>/nginx
  ```
- For apache service (rewrites /apache to /):
  ```bash
  curl http://<Gateway_IP>:<Gateway_Port>/apache
  ```

Replace `<Gateway_IP>` and `<Gateway_Port>` as appropriate for your environment.
