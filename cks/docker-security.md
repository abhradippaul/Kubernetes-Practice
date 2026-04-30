# Docker Security - TLS Configuration

Steps to secure the Docker daemon using TLS certificates.

## Generate CA Key and Certificate

```bash
mkdir -p /etc/docker/certs
cd /etc/docker/certs

openssl genpkey -algorithm RSA -out ca-key.pem
openssl req -new -x509 -days 365 -key ca-key.pem -subj "/CN=MyDockerCA" -out ca.pem
```

## Generate Server Certificate and Key

```bash
openssl genpkey -algorithm RSA -out server-key.pem
openssl req -new -key server-key.pem -subj "/CN=kplabs.docker.internal" -out server.csr
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 365 -out server-cert.pem
```

## Generate Client Certificate and Key

```bash
openssl genpkey -algorithm RSA -out client-key.pem
openssl req -new -key client-key.pem -subj "/CN=client" -out client.csr
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -days 365 -out client-cert.pem
```

## Configure Docker Daemon

Create or modify `/etc/docker/daemon.json`:

```json
{
  "tls": true,
  "tlsverify": true,
  "tlscacert": "/etc/docker/certs/ca.pem",
  "tlscert": "/etc/docker/certs/server-cert.pem",
  "tlskey": "/etc/docker/certs/server-key.pem",
  "hosts": ["tcp://0.0.0.0:2376", "unix:///var/run/docker.sock"]
}
```

## Modify Systemd Service File

Edit `/usr/lib/systemd/system/docker.service` to remove default flags from `ExecStart`:

```ini
ExecStart=/usr/bin/dockerd
```

## Restart Docker

```bash
systemctl daemon-reload
systemctl restart docker
```

## Testing the Setup

```bash
# Verify listening ports
apt-get install net-tools
netstat -ntlp

# Test insecure connection (should fail if tlsverify is true)
curl http://127.0.0.1:2376/version

# Test secure connection with certificates
curl --cert /etc/docker/certs/client-cert.pem --key /etc/docker/certs/client-key.pem --cacert /etc/docker/certs/ca.pem https://127.0.0.1:2376/version

# Test using hostname
echo "127.0.0.1 kplabs.docker.internal" >> /etc/hosts
curl --cert /etc/docker/certs/client-cert.pem --key /etc/docker/certs/client-key.pem --cacert /etc/docker/certs/ca.pem https://kplabs.docker.internal:2376/version
```
