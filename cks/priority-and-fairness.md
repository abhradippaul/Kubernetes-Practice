# API Priority and Fairness & Pod Priority

This guide covers how to manage request priority at the API level and scheduling priority for Pods in Kubernetes. These are critical for maintaining cluster stability under load.

---

## 1. API Priority and Fairness (APF)

API Priority and Fairness (APF) is a feature in the Kubernetes API server that protects the cluster from being overwhelmed by too many requests. It categorizes requests into "flows" and ensures that high-priority flows (like system components) aren't starved by low-priority ones.

### PriorityLevelConfiguration Example

A `PriorityLevelConfiguration` defines a "bucket" of capacity (concurrency) and how it handles overflow (queueing).

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: critical-priority
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 50
    limitResponse:
      type: Queue
      queue:
        queues: 64
        handSize: 6
        queueLengthLimit: 100
```

### FlowSchema Example

A `FlowSchema` matches specific requests (by user, group, or namespace) and maps them to a `PriorityLevelConfiguration`.

```yaml
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: critical-flow
spec:
  priorityLevelConfiguration:
    name: critical-priority
  matchingPrecedence: 1000
  distinguisherMethod:
    type: ByUser
  rules:
    - subjects:
        - kind: Group
          group:
            name: "system:serviceaccounts:kube-system"
      resourceRules:
        - verbs: ["*"]
          apiGroups: ["*"]
          resources: ["*"]
```

### Verification Commands

```bash
# List all FlowSchemas
kubectl get flowschemas

# List all PriorityLevelConfigurations
kubectl get prioritylevelconfigurations

# Inspect a specific FlowSchema
kubectl describe flowschema workload-low
```

---

## 2. Pod Priority and Preemption

Pod Priority allows you to indicate the importance of a Pod relative to other Pods. If a high-priority Pod cannot be scheduled due to lack of resources, the scheduler may evict (preempt) lower-priority Pods to make room.

### PriorityClass Example

First, create a `PriorityClass` object.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority-apps
value: 1000000
globalDefault: false
description: "This priority class should be used for core business applications."
```

### Using PriorityClass in a Pod

Assign the `priorityClassName` in the Pod's `spec`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: critical-app-pod
spec:
  containers:
  - name: nginx
    image: nginx
  priorityClassName: high-priority-apps
```

### Verification Commands

```bash
# List PriorityClasses
kubectl get pc

# Check the priority of a running Pod
kubectl get pod critical-app-pod -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority
```

---

## Key Takeaways

- **APF** protects the **API Server** from being overloaded by too many requests.
- **Pod Priority** protects **Business Critical Workloads** by ensuring they get scheduled even if the cluster is full.
- Use `PriorityLevelConfiguration` to define capacity and `FlowSchema` to classify traffic.
- Use `PriorityClass` to define scheduling importance.
