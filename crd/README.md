# Custom Resource Definition

## Create the CRD First

```bash
# Create the CRD
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tlscertificates.example.com # plural + group
spec:
  group: example.com # similar to a package name for classes;
  names:
    plural: tlscertificates
    singular: tlscertificate
    kind: TLSCertificate
    shortNames:
      - tls
  scope: Namespaced # Namespaced (e.g pods, deployments) or Cluster (e.g Namespace, ClusterRole).
  versions:
    - name: v1
      served: true # Set to 'true' to serve the custom resource endpoints through the API server.(e.g MutatingWebhookConfiguration)
      storage: true # Set to 'true' to persist custom resource instances to etcd
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                commonName:
                  type: string
                dnsNames: # field for DNS names associated with the certificate
                  type: array
                  items:
                    type: string
                expirationDate: # New field for the certificate expiration date
                  type: string
                  format: date-time # We specify the format as date-time
              required: # Specify the required fields here
                - commonName
                - expirationDate
EOF
```

## Create the Custom Resource

```bash
# Create the Custom Resource
kubectl apply -f - <<EOF
apiVersion: example.com/v1
kind: TLSCertificate
metadata:
  name: example-tls-cert
spec:
  commonName: example.com
  dnsNames:
    - example.com
    - www.example.com
  expirationDate: "2024-07-19T12:00:00Z"
EOF
```
