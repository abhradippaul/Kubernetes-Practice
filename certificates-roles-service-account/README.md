# Certificate

```bash
# Create secret key
openssl genrsa -out adam.key 3072

# Create certificate request
openssl req -new -key adam.key -out adam.csr -subj "/CN=adam"

# Encode
cat adam.csr | base64 | tr -d "\n"

# Create certificate request
kubectl apply -f adam-csr.yaml

# Get all certificate request
kubectl get csr

# Approve certificate
kubectl certificate approve adam-csr

# Get certificate details
kubectl get csr/adam-csr -o yaml

# Export the certificate
kubectl get csr adam-csr -o jsonpath='{.status.certificate}'| base64 -d > adam.crt

# Kubeconfig set credentials
kubectl config set-credentials adam --client-key=adam.key --client-certificate=adam.crt --embed-certs=true

# Kubeconfig set context
kubectl config set-context adam --cluster=kubernetes --user=adam

# Test context
kubectl --context adam auth whoami

# Create role
kubectl create role developer --verb=create,get,list,update,verb=delete --resource=pods,deployment

# Create rolebinding
kubectl create rolebinding developer-binding-adam --role=developer --user=adam
```

# Role based Authorization

```bash
# Verify the permission
kubectl auth can-i get pods

kubectl auth whoami

kubectl auth can-i get pods --as adam
```

```bash
# Create role
kubectl create role pod-reader --verb=get,list,watch --resource=pods,deployment

# Create rolebinding
kubectl create rolebinding admin-binding --role=pod-reader --user=adam

# Create clusterrole
kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods,deployment

# Create clusterrolebinding
kubectl create clusterrolebinding admin-binding --clusterrole=pod-reader --user=adam
```

```bash
# Namespace level resources
kubectl api-resources namespaced=true
```
