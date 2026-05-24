# Software Bill of Materials (SBOM) - BOM & Trivy

Documentation for managing SBOMs using `bom` and `trivy`.

## Reference Links

- Trivy official repository: <https://github.com/aquasecurity/trivy>
- Docker Hub page for Nginx: <https://hub.docker.com/_/nginx>

## Quick Trivy Commands

Install Trivy:

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

Scan an Nginx image:

```bash
trivy image nginx:1.19.5
```

## Install BOM

Download and install the Kubernetes SIGs `bom` tool:

```bash
wget https://github.com/kubernetes-sigs/bom/releases/download/v0.6.0/bom-amd64-linux
mv bom-amd64-linux bom
chmod +x bom
sudo mv bom /usr/local/bin
```

## Install Trivy

Install the `trivy` vulnerability and SBOM scanner:

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh
sudo mv bin/trivy /usr/local/bin
```

## BOM Usage Examples

Generate and inspect SBOMs using the `bom` tool:

```bash
# Generate SBOM for an image
bom generate spdx-json --image nginx:latest --output nginx.spdx.json

# Generate SBOM using image digest
bom generate spdx-json --image nginx@sha256:28edb1806e63847a8d6f77a7c312045e1bd91d5e3c944c8a0012f0b14c830c44 --output nginx.spdx.json

# Outline the document
bom document outline nginx.spdx.json

# Filter outline for specific packages
bom document outline nginx-spdx.json | grep dpkg
```

## Trivy Usage Examples

Generate and scan SBOMs using `trivy`:

```bash
# Generate SBOM in SPDX format
trivy image --format spdx-json --output nginx-spdx.json nginx:latest

# Generate SBOM in CycloneDX format
trivy image --format cyclonedx --output nginx-cyclone.json nginx:latest

# Scan an existing SBOM
trivy sbom nginx-spdx.json

# Scan an SBOM and write JSON output
trivy sbom nginx-spdx.json --format json --output ./sbom_check_result.json

# Scan an image for high and critical vulnerabilities
trivy image --severity HIGH,CRITICAL nginx
```
