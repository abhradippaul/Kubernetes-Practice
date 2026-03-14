# Jobs and CronJobs

```bash
# Output using imperetive command
kubectl create job busybox-job --image=busybox --dry-run=client -o yaml -- date > job.yaml

# Create using yaml file
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: busybox-job
spec:
  template:
    spec:
      containers:
      - name: busybox
        image: busybox
        command:
        - sh
        - -c
        - |
          date
      restartPolicy: Never
  backoffLimit: 4
EOF

```
