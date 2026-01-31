# PersistentVolume, PersistentVolumeClaim, StorageClass

## Setup folder in host

```bash
sudo mkdir /mnt/data/html
sudo sh -c "echo 'Hello from Kubernetes storage' > /mnt/data/html/index.html"
cat /mnt/data/html/index.html
vim /mnt/data/nginx.conf
```

## Persistent Volume

```bash
# Create PersistentVolume
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
EOF

# Verify the PersistentVolume
kubectl get pv pv-volume
```

## Persistent Volume Claim

```bash
# Create PersistentVolumeClaim
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-volume
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
EOF

# Verify the PersistentVolumeClaim
kubectl get pvc pvc-volume

# Verify the PersistentVolume
kubectl get pv pv-volume
```

# Nginx Pod

```bash
# Create Nginx Pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  nodeName: controlplane
  volumes:
    - name: pv-storage
      persistentVolumeClaim:
        claimName: pvc-volume
  containers:
  - image: nginx
    name: nginx-pod
    ports:
    - containerPort: 80
    volumeMounts:
        - name: pv-storage
          mountPath: /usr/share/nginx/html
          subPath: html
        - name: pv-storage
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
EOF

# Verify the pod
kubectl get pods
```

## Check

```bash
# Check pods
kubectl exec -it nginx-pod -- /bin/bash
apt update
apt install curl
curl http://localhost/
```

## Clean Up

```bash
# Delete all resources
kubectl delete pod nginx-pod
kubectl delete pvc pvc-volume
kubectl delete pv pv-volume

# Delete Pod
rm -rf  /mnt/data
```
