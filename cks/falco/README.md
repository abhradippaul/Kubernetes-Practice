Installation Steps:
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
sudo tee -a /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update -y
sudo apt-get install apt-transport-https
sudo apt install -y dkms make linux-headers-$(uname -r)

# If you use falcoctl driver loader to build the eBPF probe locally you need also clang toolchain

sudo apt install -y clang llvm

# You can install also the dialog package if you want it

sudo apt install -y dialog
sudo apt-get install -y falco

Start falco:
falco
Sample Rules tested:
kubectl run nginx --image=nginx
kubectl exec -it nginx -- bash
mkdir /bin/tmp-dir
cat /etc/shadow

Falco setup with helm

helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco

kubectl get pods -n falco -o wide

kubectl create deployment nginx --image=nginx
kubectl logs -f -l app.kubernetes.io/name=falco -n falco -c falco | grep Warning
kubectl exec -it $(kubectl get pods --selector=app=nginx -o name) -- cat /etc/shadow
kubectl exec -it $(kubectl get pods --selector=app=nginx -o name) -- curl localhost

custom falco rule

vim custom-rule.yaml

customRules:
custom_rules.yaml: |- - rule: Detect curl Execution in Kubernetes Pod
desc: Detects when the curl utility is executed within a Kubernetes pod.
condition: >
spawned_process and container and
proc.name = "curl"
output: >
Suspicious process detected (curl) inside a Container.
priority: WARNING

helm upgrade --namespace falco falco falcosecurity/falco --set tty=true -f custom-rule.yaml
