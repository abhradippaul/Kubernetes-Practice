# Preparing CKS

## Certificates

### Certificate Authority

```bash
# Verify the certificate CA
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt

# Content of the certificate
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

### Configure CA

```bash
# Step 1 - Creating a private key for Certificate Authority:
mkdir /root/certificates

cd /root/certificates

# Step 2 - Creating Private Key and CSR:
openssl genrsa -out ca.key 2048

openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr

# Verify the csr
openssl req -in ca.csr -text -noout

# Step 3 - Self-Sign the CSR:
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000

# Content of the certificate
openssl x509 -in ca.crt -text -noout
```

### Configure client certificate

```bash
# Step 1 - Generate Client CSR and Client Key:
cd /root/certificates

openssl genrsa -out abhra.key 2048

openssl req -new -key abhra.key -subj "/CN=abhra" -out abhra.csr

# Step 2 - Sign the Client CSR with Certificate Authority
openssl x509 -req -in abhra.csr -CA ca.crt -CAkey ca.key -out abhra.crt -days 1000

# Step 3 - Verify Client Certificate
openssl x509 -in abhra.crt -text -noout

openssl verify -CAfile ca.crt abhra.crt
```
