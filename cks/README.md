# Preparing CKS

## ETCD Security Guidelines

### Plain text data storage
```bash
# Store data in ETCD
etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt put name "Abhradip Paul"

# Get data from ETCD
etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt get name

# Print etcd data
cat /var/lib/etcd/member/snap
```

### TLS Encryption
```bash
# Listen in the port
tcpdump -i lo -x port 2379 

# Get data from ETCD
etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt get name

# Run ETCD with Secure TLS
etcd --listen-client-urls https://127.0.0.1:2379 --advertise-client-urls https://127.0.0.1 --cert-file=etcd.crt --key-file=etcd.key
```

### Certificate Based Authentication
```bash
# Store data in ETCD if authentication enabled
etcdctl --user=root:password put name "Abhradip Paul"

# Get data from ETCD if authentication enabled
etcdctl --user=root:password get name
```

### ETCD binary setup

```bash
mkdir /root/binaries

cd /root/binaries

wget https://github.com/etcd-io/etcd/releases/download/v3.5.18/etcd-v3.5.18-linux-amd64.tar.gz

tar -xzvf etcd-v3.5.18-linux-amd64.tar.gz

cd /root/binaries/etcd-v3.5.18-linux-amd64/

cp etcd etcdctl /usr/local/bin/

cd /tmp
etcd

apt install net-tools

netstat -ntlp
```

## Certificates

### Certificate Authority

```bash
# Verify the certificate CA
openssl verify -CAfile ca.crt client.crt

# Content of the certificate
openssl x509 -in client.crt -text -noout
```

### Configure CA
```bash
# Step 1 - Creating a private key for Certificate Authority:
mkdir /root/certificates

cd /root/certificates

# Step 2 - Creating Private Key and CSR:
openssl genrsa -out ca.key 2048

openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr

# Step 3 - Self-Sign the CSR:
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000

# Content of the certificate
openssl x509 -in client.crt -text -noout
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


### Configure ETCD certificate
```bash
# Pre-Requisite: Install Network Utilities
apt-get -y install tcpdump net-tools

# Step 1 - Capture Plain Text ETCD Traffic
# First tab:
cd /tmp
etcd

# Second tab:
tcpdump -i lo -X  port 2379

# Third tab:
etcdctl put course "cks"
etcdctl get course

# Step 2 - Creating the etcd Key:
cd /root/certificates
openssl genrsa -out etcd.key 2048

# Step 3 - Creating Configuration for etcd CSR:
# Replace the IP.1 with your Server IP
cat > etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = [IP-1]
IP.2 = 127.0.0.1
EOF

# Step 4 - Creating CSR:
openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr -config etcd.cnf

# Step 5 - Sign etcd CSR with Certificate Authority Certificate:
openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out etcd.crt -extensions v3_req -extfile etcd.cnf -days 2000

# Step 6 - Start Etcd Server with HTTPS:
etcd --cert-file=/root/certificates/etcd.crt --key-file=/root/certificates/etcd.key --advertise-client-urls=https://127.0.0.1:2379 --listen-client-urls=https://127.0.0.1:2379

# Step 7 - Verification
# Below command should not work.
etcdctl put course "cks"

# Step 8 - Store and Fetch Data by skipping TLS Verification
etcdctl --endpoints=https://127.0.0.1:2379 --insecure-skip-tls-verify --insecure-transport=false put course "cks"

etcdctl --endpoints=https://127.0.0.1:2379 --insecure-skip-tls-verify --insecure-transport=false get course
```

### Configure mutual TLS (mTLS)

Mutual TLS (mTLS) ensures that both the client and the server verify each other's certificates, providing a higher level of security than standard TLS.

Generate a private key and a certificate for the client, signed by the trusted Certificate Authority (CA).

```bash
# Step 1: Generate Client Certificate and Key
cd /root/certificates

# Generate private key for the client
openssl genrsa -out client.key 2048

# Create a Certificate Signing Request (CSR)
openssl req -new -key client.key -subj "/CN=client" -out client.csr

# Sign the CSR with the CA to create the client certificate
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -extensions v3_req -days 2000

# Step 2: Start Etcd Server with mTLS Enabled
# The `--client-cert-auth` flag enforces that any client connecting must provide a valid certificate signed by the `--trusted-ca-file`.

cd /root/certificates

etcd --cert-file=etcd.crt \
     --key-file=etcd.key \
     --advertise-client-urls=https://127.0.0.1:2379 \
     --listen-client-urls=https://127.0.0.1:2379 \
     --client-cert-auth \
     --trusted-ca-file=ca.crt

# Step 3: Connect to Etcd using mTLS
# To interact with the secured Etcd server, you must provide the CA certificate, the client certificate, and the client private key.

cd /root/certificates

# Store a value
etcdctl --endpoints=https://127.0.0.1:2379 \
        --cacert=ca.crt \
        --cert=client.crt \
        --key=client.key \
        put key1 "value1"

# Fetch the value
etcdctl --endpoints=https://127.0.0.1:2379 \
        --cacert=ca.crt \
        --cert=client.crt \
        --key=client.key \
        get key1
```

### ETCD Systemd
```bash
Step 1: Create Data Directory for etcd
mkdir /var/lib/etcd
chmod 700 /var/lib/etcd
Step 2: Create Systemd file for etcd
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --cert-file=/root/certificates/etcd.crt \\
  --key-file=/root/certificates/etcd.key \\
  --trusted-ca-file=/root/certificates/ca.crt \\
  --client-cert-auth \\
  --listen-client-urls https://127.0.0.1:2379 \\
  --advertise-client-urls https://127.0.0.1:2379 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
Step 3: Start etcd
systemctl start etcd

systemctl enable etcd
Step 4: Verify the status
systemctl status etcd
Step 5: Check etcd Logs
journalctl -u etcd
```