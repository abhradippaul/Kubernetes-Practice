# Taint and Toleration

## Taint on node
```bash
# Adding taint on the node
kubectl taint node node01 gpu=true:NoSchedule

# Review the node
kubectl describe node node01 | grep -i taint

# Remove taint on the node
kubectl taint node node01 gpu=true:NoSchedule-
```

## Add label on node
```bash
# Adding label on the node
kubectl label node node01 gpu=true

# Review the node
kubectl get nodes --show-labels

# Remove label on the node
kubectl label node node01 gpu=true-
```