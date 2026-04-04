# ETCD Encryption at Rest

This guide covers the steps to encrypt Kubernetes Secrets at rest in ETCD.

## Documentation Reference

- [Encrypting Confidential Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

---

## Step 1: Create a New Secret

Create a secret to verify its initial (unencrypted) state in ETCD.

```bash
kubectl create secret generic new-secret -n default \
--from-literal=user=secretpassword

kubectl get secret
```

## Step 2: Find the Secret in ETCD (Plain-Text)

Verify that the secret is stored in plain-text or easily readable format.

```bash

ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
--insecure-skip-tls-verify  --insecure-transport=false \
--cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
--key /etc/kubernetes/pki/apiserver-etcd-client.key \
get /registry/secrets/default/new-secret | hexdump -C

cd /var/lib/etcd
grep -R "secretpassword" .
```

## Step 3: Create Encryption Key

Generate a 32-byte random key and base64 encode it.

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
echo $ENCRYPTION_KEY
```

## Step 4: Create Encryption Config

Create the `EncryptionConfiguration` file.

```bash
cat > encryption-at-rest.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

## Step 5: Copy Configuration to Appropriate Path

Move the configuration file to the Kubernetes directory.

```bash
mkdir -p /etc/kubernetes/enc
cp encryption-at-rest.yaml /etc/kubernetes/enc
```

## Step 6: Configure kube-apiserver

Update the `kube-apiserver` service or static pod manifest to use the encryption provider.

```bash
# Edit the service file (if running as a systemd service)
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml

- --encryption-provider-config=/etc/kubernetes/enc/encryption-at-rest.yaml

# Add the following flag:
# --encryption-provider-config=/var/lib/kubernetes/encryption-at-rest.yaml

volumeMounts:
  - name: enc
    mountPath: /etc/kubernetes/enc
    readOnly: true

volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

## Step 7: Create a New Secret (Post-Encryption)

Create another secret to verify that it is now encrypted.

```bash
kubectl create secret generic db-secret -n default \
--from-literal=dbadmin=dbpasswd

kubectl get secret
```

## Step 8: Verify Encryption in ETCD

Check if the new secret is encrypted in ETCD.

```bash

ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
--insecure-skip-tls-verify  --insecure-transport=false \
--cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
--key /etc/kubernetes/pki/apiserver-etcd-client.key \
get /registry/secrets/default/new-secret | hexdump -C

cd /var/lib/etcd
grep -R "dbpasswd" .
```
