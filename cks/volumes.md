# Kubernetes Volumes for CKS

This note covers common CKS-focused volume use cases, especially `projected` volumes with `Secret`, `ConfigMap`, and `ServiceAccount` tokens.

## What You Will Practice

- Create a `Secret` and `ConfigMap`
- Mount both resources into a Pod using a projected volume
- Disable automatic service account token mounting
- Manually mount a service account token with a projected volume
- Use a custom service account in a Pod

## 1. Create a Secret and ConfigMap

Create the resources that will later be mounted inside the Pod.

```bash
kubectl create secret generic firstsecret \
  --from-literal=dbpassword=mypassword123

kubectl create configmap my-config \
  --from-literal=config-key="This is a config value"
```

## 2. Create a Pod with a Projected Volume

A projected volume lets you combine multiple volume sources into a single mount path.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
spec:
  containers:
    - name: container-test
      image: busybox:1.37
      command: ["sleep", "3600"]
      volumeMounts:
        - name: all-in-one
          mountPath: /projected-volume
          readOnly: true
  volumes:
    - name: all-in-one
      projected:
        sources:
          - secret:
              name: firstsecret
              items:
                - key: dbpassword
                  path: my-username
          - configMap:
              name: my-config
              items:
                - key: config-key
                  path: my-config
```

Apply and verify:

```bash
kubectl apply -f projected-volume.yaml
kubectl exec -it volume-test -- sh
cd /projected-volume
ls -l
cat my-username
cat my-config
```

Cleanup:

```bash
kubectl delete -f projected-volume.yaml
```

## 3. Disable Auto-Mounting for the Default Service Account

Create a namespace and disable automatic token mounting for the default service account.

```bash
kubectl create namespace test-ns
kubectl edit sa default -n test-ns
```

Add this field to the service account:

```yaml
automountServiceAccountToken: false
```

## 4. Mount a Service Account Token with a Projected Volume

Even when automatic mounting is disabled, you can still mount a token manually using a projected volume.

Create `sa-example-1.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa
  namespace: test-ns
spec:
  containers:
    - name: container-test
      image: busybox:1.37
      command: ["sleep", "3600"]
      volumeMounts:
        - name: token-vol
          mountPath: /service-account
          readOnly: true
  volumes:
    - name: token-vol
      projected:
        sources:
          - serviceAccountToken:
              audience: api
              expirationSeconds: 3600
              path: token
```

Create and verify:

```bash
kubectl apply -f sa-example-1.yaml
kubectl exec -n test-ns -it pod-sa -- sh
ls -l /service-account
cat /service-account/token
```

Cleanup:

```bash
kubectl delete -f sa-example-1.yaml
```

## 5. Mount a Custom Service Account

Create a custom service account with `automountServiceAccountToken: false`.

Create `custom-sa.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: custom-sa
  namespace: test-ns
automountServiceAccountToken: false
```

Apply it:

```bash
kubectl apply -f custom-sa.yaml
```

Now create `sa-example-2.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-sa-custom
  namespace: test-ns
spec:
  serviceAccountName: custom-sa
  containers:
    - name: container-test
      image: busybox:1.37
      command: ["sleep", "3600"]
      volumeMounts:
        - name: token-vol
          mountPath: /service-account
          readOnly: true
  volumes:
    - name: token-vol
      projected:
        sources:
          - serviceAccountToken:
              audience: api
              expirationSeconds: 3600
              path: token
```

Create and verify:

```bash
kubectl apply -f sa-example-2.yaml
kubectl exec -n test-ns -it pod-sa-custom -- sh
ls -l /service-account
cat /service-account/token
```

## Cleanup

Delete the namespace and all resources created inside it:

```bash
kubectl delete ns test-ns
```

## Quick Summary

- `projected` volumes combine data from multiple sources into one directory
- `Secret` and `ConfigMap` can be mounted together in the same path
- `automountServiceAccountToken: false` prevents automatic token injection
- `serviceAccountToken` inside a projected volume gives fine-grained control over token mounting
