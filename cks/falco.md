Falco setup with helm

helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
 --create-namespace \
 --namespace falco

kubectl get pods -n falco -o wide

NAME READY STATUS RESTARTS AGE IP NODE NOMINATED NODE READINESS GATES
falco-25zgj 2/2 Running 0 93s 192.168.1.118 node01 <none> <none>
falco-pxskz 2/2 Running 0 93s 192.168.0.195 controlplane <none> <none>

custom falco rule

vim custom-rule.yaml

customRules:
rules-bash-detection.yaml: |- - rule: Terminal shell in container
desc: A shell was spawned by a container with an attached terminal.
condition: >
spawned_process
and container
and proc.name = bash
and proc.tty != 0
output: >
A shell was spawned in a container
(user=%user.name container_id=%container.id
container_name=%container.name shell=%proc.name
cmdline=%proc.cmdline terminal=%proc.tty)
priority: WARNING
tags: [container, shell]

helm upgrade --install -n falco falco falcosecurity/falco -f custom-rule.yaml
