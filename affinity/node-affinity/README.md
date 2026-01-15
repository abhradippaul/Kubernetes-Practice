# Node Affinity

## Node Label

```bash
# Add label to node
kubectl label node node01 disktype=hdd

# Remove label from node
kubectl label node node01 disktype-

# Add non value label
kubectl label node node01 disktype=
```