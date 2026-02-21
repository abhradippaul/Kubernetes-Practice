# Learning StatefulSet

## Configure StorageClass and PV
```bash
# Storage Class mannual
kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: postgres-local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
EOF

# Create Multiple PV to bond with PVC

# Create PV 1
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-volume-01
  labels:
    type: local
spec:
  storageClassName: postgres-local-storage
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data-01
EOF

# Create PV 2
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-volume-02
  labels:
    type: local
spec:
  storageClassName: postgres-local-storage
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data-02
EOF

# Create PV 3
kubectl apply -f - << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv-volume-03
  labels:
    type: local
spec:
  storageClassName: postgres-local-storage
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /mnt/data-03
EOF
```

# Create Postgres

```bash
# Create Configmap
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  primary.conf: |
    wal_level = replica
    max_wal_senders = 10
    wal_keep_size = 512MB
    hot_standby = on

  pg_hba.conf: |
    host replication replicator 0.0.0.0/0 md5
    host all all 0.0.0.0/0 md5
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
stringData:
  POSTGRES_PASSWORD: postgres
  REPLICATION_PASSWORD: postgres
---
EOF

# Create Headless Service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  labels:
    app: postgres-statefulset
spec:
  ports:
  - port: 5432
    targetPort: 5432
    name: postgres
  clusterIP: None
  selector:
    app: postgres-statefulset
EOF

# Create StatefulSet
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app: postgres-statefulset
  name: postgres-statefulset
spec:
  serviceName: postgres-service
  minReadySeconds: 20
  replicas: 3
  selector:
    matchLabels:
      app: postgres-statefulset
  template:
    metadata:
      labels:
        app: postgres-statefulset
    spec:
      nodeName: node01
      terminationGracePeriodSeconds: 30
      volumes:
        - name: config
          configMap:
            name: postgres-config
      containers:
        - image: postgres
          name: postgres
          ports:
            - containerPort: 5432
              name: postgres
          command: ["/bin/bash", "-c"]
          args:
            - |
              set -e

              if [ ! -s "$PGDATA/PG_VERSION" ]; then

                ORDINAL="${HOSTNAME##*-}"

                if [[ "$ORDINAL" == "0" ]]; then
                  echo "Primary starting normally..."
                else
                  echo "Replica setup..."

                  until pg_isready -h postgres-statefulset-0.postgres-service; do
                    sleep 2
                  done

                  rm -rf $PGDATA/*
                  PGPASSWORD=$REPLICATION_PASSWORD pg_basebackup \
                    -h postgres-statefulset-0.postgres-service \
                    -D $PGDATA \
                    -U replicator \
                    -Fp -Xs -P -R
                fi
              fi

              exec docker-entrypoint.sh postgres
          envFrom:
          - secretRef:
              name: postgres-secret
          volumeMounts:
          - name: postgres-data
            mountPath: /var/lib/postgresql/data
          - name: config
            mountPath: /config
          resources:
            limits:
              cpu: 100m
              memory: 200Mi
            requests:
              cpu: 100m
              memory: 200Mi

  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: postgres-local-storage
      resources:
        requests:
          storage: 100Mi
EOF
```