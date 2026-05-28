#!/usr/bin/env bash
# =============================================================================
# CKS Exam — Answer Verification Script
# Target : kubeadm cluster (Ubuntu 22.04 / 24.04), controlplane node
# Run as : root  (sudo -i first)
# Usage  : bash cks-exam-check.sh [--task <1-15|all>] [--verbose]
# =============================================================================
set -uo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';   GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';     RESET='\033[0m'
PASS="${GREEN}✔ PASS${RESET}"; FAIL="${RED}✘ FAIL${RESET}"; SKIP="${YELLOW}– SKIP${RESET}"

# ── Globals ───────────────────────────────────────────────────────────────────
TASK="all"
VERBOSE=false
TOTAL=0; PASSED=0; FAILED=0; SKIPPED=0
declare -A TASK_RESULTS=()   # task_num -> "P/F/S counts"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --task)    TASK="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Usage: $0 [--task <1-15|all>] [--verbose]" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
header() {
  echo -e "\n${BOLD}${CYAN}┌──────────────────────────────────────────────────────┐${RESET}"
  printf "${BOLD}${CYAN}│  %-52s│${RESET}\n" "$*"
  echo -e "${BOLD}${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
}

_cur_task_p=0; _cur_task_f=0; _cur_task_s=0

check() {
  # check <description> <command_or_expression>
  local desc="$1"; shift
  local result
  TOTAL=$(( TOTAL + 1 ))
  if eval "$@" &>/dev/null 2>&1; then
    echo -e "  ${PASS}  ${desc}"
    PASSED=$(( PASSED + 1 )); _cur_task_p=$(( _cur_task_p + 1 ))
  else
    echo -e "  ${FAIL}  ${desc}"
    FAILED=$(( FAILED + 1 )); _cur_task_f=$(( _cur_task_f + 1 ))
    if $VERBOSE; then
      echo -e "         ${YELLOW}cmd: $*${RESET}"
      eval "$@" 2>&1 | sed 's/^/         /' || true
    fi
  fi
}

check_skip() {
  local desc="$1"
  echo -e "  ${SKIP}  ${desc}"
  TOTAL=$(( TOTAL + 1 )); SKIPPED=$(( SKIPPED + 1 ))
  _cur_task_s=$(( _cur_task_s + 1 ))
}

begin_task() {
  _cur_task_p=0; _cur_task_f=0; _cur_task_s=0
}

end_task() {
  local tnum="$1"
  TASK_RESULTS[$tnum]="${_cur_task_p}P ${_cur_task_f}F ${_cur_task_s}S"
}

kget() { kubectl get "$@" 2>/dev/null; }
kexist() { kubectl get "$@" &>/dev/null 2>&1; }

# ── Wait helper ───────────────────────────────────────────────────────────────
pod_running() {
  local ns="$1" name_pattern="$2"
  kubectl get pods -n "$ns" 2>/dev/null \
    | grep -E "$name_pattern" \
    | grep -q "Running"
}

# =============================================================================
# TASK 1 — AppArmor + Least-Privilege SA (omni namespace)
# =============================================================================
check_task1() {
  header "Task 1 — AppArmor + Least-Privilege SA (omni namespace)"
  begin_task

  # 1. AppArmor profile loaded
  check "AppArmor profile 'restricted-frontend' is loaded" \
    "aa-status 2>/dev/null | grep -q 'restricted-frontend'"

  # 2. Pod exists in omni namespace
  check "Pod 'frontend-site' exists in omni namespace" \
    "kexist pod frontend-site -n omni"

  # 3. Pod uses correct service account
  check "Pod uses serviceAccount 'frontend-default'" \
    "[[ \$(kubectl get pod frontend-site -n omni -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null) == 'frontend-default' ]]"

  # 4. AppArmor annotation present on pod
  check "Pod has AppArmor profile type 'Localhost'" \
    "kubectl get pod frontend-site -n omni -o jsonpath='{.spec.securityContext.appArmorProfile.type}' 2>/dev/null | grep -q 'Localhost'"

  check "Pod AppArmor localhostProfile is 'restricted-frontend'" \
    "kubectl get pod frontend-site -n omni -o jsonpath='{.spec.securityContext.appArmorProfile.localhostProfile}' 2>/dev/null | grep -q 'restricted-frontend'"

  # 5. Pod is running
  check "Pod 'frontend-site' is in Running state" \
    "pod_running omni frontend-site"

  # 6. Unused service accounts deleted
  check "Service account 'frontend' deleted from omni" \
    "! kexist sa frontend -n omni"

  check "Service account 'fe' deleted from omni" \
    "! kexist sa fe -n omni"

  # 7. frontend-default still present
  check "Service account 'frontend-default' still exists in omni" \
    "kexist sa frontend-default -n omni"

  end_task 1
}

# =============================================================================
# TASK 2 — Secrets as Mounted Volume (orion namespace)
# =============================================================================
check_task2() {
  header "Task 2 — Secrets as Mounted Volume (orion namespace)"
  begin_task

  # 1. Decoded secret file exists
  check "File /root/CKS/secrets/CONNECTOR_PASSWORD exists" \
    "[[ -f /root/CKS/secrets/CONNECTOR_PASSWORD ]]"

  # 2. Decoded content is correct
  check "CONNECTOR_PASSWORD file contains the decoded secret value" \
    "grep -q 'S3cur3P@ssw0rd!' /root/CKS/secrets/CONNECTOR_PASSWORD 2>/dev/null"

  # 3. Pod exists
  check "Pod 'connector-pod' exists in orion namespace" \
    "kexist pod connector-pod -n orion"

  # 4. Pod is running
  check "Pod 'connector-pod' is in Running state" \
    "pod_running orion connector-pod"

  # 5. Secret NOT used as env var anymore
  check "Secret is NOT mounted as environment variable in the pod" \
    "! kubectl get pod connector-pod -n orion -o jsonpath='{.spec.containers[0].env}' 2>/dev/null | grep -q 'CONNECTOR_PASSWORD'"

  # 6. Secret volume mounted
  check "Pod has a secret volume defined" \
    "kubectl get pod connector-pod -n orion -o jsonpath='{.spec.volumes}' 2>/dev/null | grep -q 'secret'"

  # 7. Mounted at correct path
  check "Volume is mounted at /mnt/connector/password" \
    "kubectl get pod connector-pod -n orion -o jsonpath='{.spec.containers[0].volumeMounts}' 2>/dev/null | grep -q '/mnt/connector/password'"

  # 8. Mount is read-only
  check "Volume mount is read-only" \
    "kubectl get pod connector-pod -n orion -o json 2>/dev/null | grep -A5 'mnt/connector/password' | grep -q 'true'"

  end_task 2
}

# =============================================================================
# TASK 3 — Static Analysis: Credential Exposure
# =============================================================================
check_task3() {
  header "Task 3 — Static Analysis: Credential Exposure (/opt/course/)"
  begin_task

  # 1. security-issues.txt exists
  check "File /opt/course/security-issues.txt exists" \
    "[[ -f /opt/course/security-issues.txt ]]"

  # 2. File is not empty
  check "/opt/course/security-issues.txt is not empty" \
    "[[ -s /opt/course/security-issues.txt ]]"

  # 3. Correct files identified
  check "Dockerfile.backend listed in security-issues.txt" \
    "grep -q 'Dockerfile.backend' /opt/course/security-issues.txt 2>/dev/null"

  check "deployment-app.yaml listed in security-issues.txt" \
    "grep -q 'deployment-app.yaml' /opt/course/security-issues.txt 2>/dev/null"

  check "configmap-bad.yaml listed in security-issues.txt" \
    "grep -q 'configmap-bad.yaml' /opt/course/security-issues.txt 2>/dev/null"

  # 4. Clean files NOT listed (false positives)
  check "Dockerfile.frontend NOT listed (no credentials in it)" \
    "! grep -q 'Dockerfile.frontend' /opt/course/security-issues.txt 2>/dev/null"

  check "configmap-safe.yaml NOT listed (no credentials in it)" \
    "! grep -q 'configmap-safe.yaml' /opt/course/security-issues.txt 2>/dev/null"

  end_task 3
}

# =============================================================================
# TASK 4 — Seccomp Audit Profile
# =============================================================================
check_task4() {
  header "Task 4 — Seccomp Audit Profile for audit-nginx"
  begin_task

  # 1. audit.json moved to seccomp profiles dir
  check "audit.json present at /var/lib/kubelet/seccomp/profiles/audit.json" \
    "[[ -f /var/lib/kubelet/seccomp/profiles/audit.json ]]"

  # 2. audit.json is valid JSON
  check "audit.json is valid JSON" \
    "python3 -c 'import json,sys; json.load(open(\"/var/lib/kubelet/seccomp/profiles/audit.json\"))' 2>/dev/null"

  # 3. Pod exists
  check "Pod 'audit-nginx' exists in default namespace" \
    "kexist pod audit-nginx -n default"

  # 4. Pod is running
  check "Pod 'audit-nginx' is in Running state" \
    "pod_running default audit-nginx"

  # 5. Correct image
  check "Pod uses image 'nginx:alpine'" \
    "kubectl get pod audit-nginx -n default -o jsonpath='{.spec.containers[0].image}' 2>/dev/null | grep -q 'nginx:alpine'"

  # 6. Seccomp profile type
  check "Pod seccompProfile type is 'Localhost'" \
    "kubectl get pod audit-nginx -n default -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null | grep -q 'Localhost'"

  # 7. Seccomp profile path
  check "Pod seccompProfile localhostProfile is 'profiles/audit.json'" \
    "kubectl get pod audit-nginx -n default -o jsonpath='{.spec.securityContext.seccompProfile.localhostProfile}' 2>/dev/null | grep -q 'profiles/audit.json'"

  end_task 4
}

# =============================================================================
# TASK 5 — CIS Benchmark Fixes
# =============================================================================
check_task5() {
  header "Task 5 — CIS Benchmark Fixes (kubelet / etcd / control plane)"
  begin_task

  # 1. Kubelet service file permissions
  check "kubelet.service has permissions 600" \
    "[[ \$(stat -c '%a' /usr/lib/systemd/system/kubelet.service 2>/dev/null) == '600' ]]"

  # 2. Kubelet config.yaml permissions
  check "kubelet config.yaml has permissions 600" \
    "[[ \$(stat -c '%a' /var/lib/kubelet/config.yaml 2>/dev/null) == '600' ]]"

  # 3. etcd directory ownership
  check "etcd directory owned by etcd:etcd" \
    "[[ \$(stat -c '%U:%G' /var/lib/etcd 2>/dev/null) == 'etcd:etcd' ]]"

  # 4. kube-controller-manager profiling disabled
  check "kube-controller-manager has --profiling=false" \
    "grep -q '\-\-profiling=false' /etc/kubernetes/manifests/kube-controller-manager.yaml 2>/dev/null"

  # 5. kube-scheduler profiling disabled
  check "kube-scheduler has --profiling=false" \
    "grep -q '\-\-profiling=false' /etc/kubernetes/manifests/kube-scheduler.yaml 2>/dev/null"

  # 6. controller-manager pod is still running
  check "kube-controller-manager pod is Running after changes" \
    "kubectl get pods -n kube-system 2>/dev/null | grep 'kube-controller-manager' | grep -q 'Running'"

  # 7. kube-scheduler pod is still running
  check "kube-scheduler pod is Running after changes" \
    "kubectl get pods -n kube-system 2>/dev/null | grep 'kube-scheduler' | grep -q 'Running'"

  end_task 5
}

# =============================================================================
# TASK 6 — Falco Rule Override
# =============================================================================
check_task6() {
  header "Task 6 — Falco Rule Override (CRITICAL priority)"
  begin_task

  # 1. falco_rules.local.yaml has the rule
  check "falco_rules.local.yaml contains 'Write below binary dir' rule" \
    "grep -q 'Write below binary dir' /etc/falco/falco_rules.local.yaml 2>/dev/null"

  # 2. Priority set to CRITICAL
  check "Rule priority is set to CRITICAL" \
    "grep -q 'priority: CRITICAL' /etc/falco/falco_rules.local.yaml 2>/dev/null"

  # 3. Output format correct — user_id
  check "Rule output contains 'user_id=%user.uid'" \
    "grep -q 'user_id=%user.uid' /etc/falco/falco_rules.local.yaml 2>/dev/null"

  # 4. Output format correct — file_updated
  check "Rule output contains 'file_updated=%fd.name'" \
    "grep -q 'file_updated=%fd.name' /etc/falco/falco_rules.local.yaml 2>/dev/null"

  # 5. Output format correct — command
  check "Rule output contains 'command=%proc.cmdline'" \
    "grep -q 'command=%proc.cmdline' /etc/falco/falco_rules.local.yaml 2>/dev/null"

  # 6. file_output enabled in falco.yaml
  check "falco.yaml has file_output enabled" \
    "grep -A3 'file_output:' /etc/falco/falco.yaml 2>/dev/null | grep -q 'enabled: true'"

  # 7. Correct log path configured
  check "falco.yaml file_output filename is /opt/security_incidents/alerts.log" \
    "grep -q '/opt/security_incidents/alerts.log' /etc/falco/falco.yaml 2>/dev/null"

  # 8. Falco service is running
  check "Falco service is active/running" \
    "systemctl is-active falco &>/dev/null"

  # 9. Alert log file exists
  check "Alert log file exists at /opt/security_incidents/alerts.log" \
    "[[ -f /opt/security_incidents/alerts.log ]]"

  # 10. Default rules file NOT modified
  check "Default rules file /etc/falco/falco_rules.yaml was NOT modified" \
    "! grep -q 'priority: CRITICAL' /etc/falco/falco_rules.yaml 2>/dev/null"

  end_task 6
}

# =============================================================================
# TASK 7 — SBOM SPDX
# =============================================================================
check_task7() {
  header "Task 7 — SBOM SPDX (fruits deployment / salad namespace)"
  begin_task

  # 1. bugged-container.txt exists
  check "~/bugged-container.txt exists" \
    "[[ -f ~/bugged-container.txt ]]"

  # 2. Correct container identified
  check "~/bugged-container.txt contains 'kiwi'" \
    "grep -q 'kiwi' ~/bugged-container.txt 2>/dev/null"

  # 3. bugged-fruit.spdx exists
  check "~/bugged-fruit.spdx file exists" \
    "[[ -f ~/bugged-fruit.spdx ]]"

  # 4. SPDX file is not empty
  check "~/bugged-fruit.spdx is not empty" \
    "[[ -s ~/bugged-fruit.spdx ]]"

  # 5. SPDX file is valid JSON
  check "~/bugged-fruit.spdx is valid JSON" \
    "python3 -c 'import json,sys; json.load(open(os.path.expanduser(\"~/bugged-fruit.spdx\")))' 2>/dev/null || \
     python3 -c 'import json; json.load(open(\"/root/bugged-fruit.spdx\"))' 2>/dev/null"

  # 6. SPDX format markers present
  check "SPDX file contains SPDXID field" \
    "grep -q 'SPDXID' ~/bugged-fruit.spdx 2>/dev/null"

  check "SPDX file contains spdxVersion field" \
    "grep -q 'spdxVersion' ~/bugged-fruit.spdx 2>/dev/null"

  end_task 7
}

# =============================================================================
# TASK 8 — Service Account with Projected Token
# =============================================================================
check_task8() {
  header "Task 8 — SA with Projected Token (automated namespace)"
  begin_task

  # 1. bot-sa exists
  check "ServiceAccount 'bot-sa' exists in automated namespace" \
    "kexist sa bot-sa -n automated"

  # 2. automountServiceAccountToken is false
  check "bot-sa has automountServiceAccountToken: false" \
    "[[ \$(kubectl get sa bot-sa -n automated -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null) == 'false' ]]"

  # 3. sweeper deployment uses bot-sa
  check "sweeper deployment uses serviceAccountName 'bot-sa'" \
    "kubectl get deployment sweeper -n automated \
       -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null | grep -q 'bot-sa'"

  # 4. Projected volume defined
  check "sweeper pod template has a projected volume" \
    "kubectl get deployment sweeper -n automated \
       -o jsonpath='{.spec.template.spec.volumes}' 2>/dev/null | grep -q 'projected'"

  # 5. serviceAccountToken in projected sources
  check "Projected volume includes serviceAccountToken source" \
    "kubectl get deployment sweeper -n automated \
       -o json 2>/dev/null | grep -q 'serviceAccountToken'"

  # 6. Volume is mounted in the container
  check "sweeper container mounts the projected token volume" \
    "kubectl get deployment sweeper -n automated \
       -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}' 2>/dev/null | grep -q '.'"

  # 7. Pods are running
  check "sweeper pods are Running" \
    "kubectl get pods -n automated 2>/dev/null | grep sweeper | grep -q Running"

  end_task 8
}

# =============================================================================
# TASK 9 — Fix Non-Running web-server (restricted namespace)
# =============================================================================
check_task9() {
  header "Task 9 — Fix Non-Running web-server (restricted namespace)"
  begin_task

  # 1. Namespace label NOT changed
  check "restricted namespace still has enforce=restricted PSA label" \
    "kubectl get ns restricted --show-labels 2>/dev/null | grep -q 'pod-security.kubernetes.io/enforce=restricted'"

  # 2. Deployment exists
  check "web-server deployment exists in restricted namespace" \
    "kexist deployment web-server -n restricted"

  # 3. Image unchanged
  check "Container image is still nginx:alpine" \
    "kubectl get deployment web-server -n restricted \
       -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | grep -q 'nginx:alpine'"

  # 4. Pods are running
  check "web-server pods are in Running state" \
    "kubectl get pods -n restricted 2>/dev/null | grep web-server | grep -q Running"

  # 5. allowPrivilegeEscalation false
  check "allowPrivilegeEscalation is false" \
    "kubectl get deployment web-server -n restricted \
       -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null \
       | grep -q 'false'"

  # 6. runAsNonRoot true
  check "runAsNonRoot is true" \
    "kubectl get deployment web-server -n restricted \
       -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null \
       | grep -q 'true'"

  # 7. seccompProfile defined
  check "seccompProfile is defined (RuntimeDefault or Localhost)" \
    "kubectl get deployment web-server -n restricted \
       -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null \
       | grep -qE 'RuntimeDefault|Localhost'"

  end_task 9
}

# =============================================================================
# TASK 10 — Network Policy
# =============================================================================
check_task10() {
  header "Task 10 — Network Policy (products / database / payments)"
  begin_task

  # 1. NetworkPolicy exists
  check "NetworkPolicy 'allow-traffic-to-products' exists in products namespace" \
    "kexist networkpolicy allow-traffic-to-products -n products"

  # 2. Correct pod selector
  check "NetworkPolicy selects pods with label app=web-app" \
    "kubectl get networkpolicy allow-traffic-to-products -n products \
       -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null | grep -q 'web-app'"

  # 3. Ingress policy type
  check "NetworkPolicy policyType includes Ingress" \
    "kubectl get networkpolicy allow-traffic-to-products -n products \
       -o jsonpath='{.spec.policyTypes}' 2>/dev/null | grep -q 'Ingress'"

  # 4. database namespace selector in ingress rules
  check "Ingress rule includes namespaceSelector for database namespace" \
    "kubectl get networkpolicy allow-traffic-to-products -n products \
       -o json 2>/dev/null | grep -q 'database'"

  # 5. database pod selector (app=database)
  check "Ingress rule includes podSelector for app=database" \
    "kubectl get networkpolicy allow-traffic-to-products -n products \
       -o json 2>/dev/null | grep -q '\"database\"'"

  # 6. payments namespace selector
  check "Ingress rule includes namespaceSelector for payments namespace" \
    "kubectl get networkpolicy allow-traffic-to-products -n products \
       -o json 2>/dev/null | grep -q 'payments'"

  end_task 10
}

# =============================================================================
# TASK 11 — Security Context: gamma Deployment
# =============================================================================
check_task11() {
  header "Task 11 — Security Context: gamma (galaxy namespace)"
  begin_task

  local containers
  containers=$(kubectl get deployment gamma -n galaxy \
    -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null)

  check "gamma deployment exists in galaxy namespace" \
    "kexist deployment gamma -n galaxy"

  # Check each container
  local idx=0
  for cname in $containers; do
    check "Container '$cname': runAsUser is 1001" \
      "[[ \$(kubectl get deployment gamma -n galaxy \
           -o jsonpath=\"{.spec.template.spec.containers[${idx}].securityContext.runAsUser}\" \
           2>/dev/null) == '1001' ]]"

    check "Container '$cname': allowPrivilegeEscalation is false" \
      "[[ \$(kubectl get deployment gamma -n galaxy \
           -o jsonpath=\"{.spec.template.spec.containers[${idx}].securityContext.allowPrivilegeEscalation}\" \
           2>/dev/null) == 'false' ]]"

    check "Container '$cname': readOnlyRootFilesystem is true" \
      "[[ \$(kubectl get deployment gamma -n galaxy \
           -o jsonpath=\"{.spec.template.spec.containers[${idx}].securityContext.readOnlyRootFilesystem}\" \
           2>/dev/null) == 'true' ]]"

    idx=$(( idx + 1 ))
  done

  check "gamma pods are Running" \
    "kubectl get pods -n galaxy 2>/dev/null | grep gamma | grep -q Running"

  end_task 11
}

# =============================================================================
# TASK 12 — TLS Ingress: rocket-server
# =============================================================================
check_task12() {
  header "Task 12 — TLS Ingress: rocket-server (space namespace)"
  begin_task

  # 1. Ingress exists
  check "Ingress 'rocket-ingress' exists in space namespace" \
    "kexist ingress rocket-ingress -n space"

  # 2. Correct hostname
  check "Ingress rule host is 'rocket-server.local'" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.rules[0].host}' 2>/dev/null | grep -q 'rocket-server.local'"

  # 3. Path is /
  check "Ingress rule path is '/'" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null | grep -q '^/$'"

  # 4. Backend service name
  check "Ingress backend service is 'rocket-server'" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null | grep -q 'rocket-server'"

  # 5. TLS configured
  check "Ingress has TLS section defined" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.tls}' 2>/dev/null | grep -q '.'"

  # 6. Correct TLS secret
  check "Ingress TLS uses secret 'rocket-tls'" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null | grep -q 'rocket-tls'"

  # 7. TLS host matches
  check "Ingress TLS host includes 'rocket-server.local'" \
    "kubectl get ingress rocket-ingress -n space \
       -o json 2>/dev/null | grep -q 'rocket-server.local'"

  # 8. ingressClassName is nginx
  check "Ingress ingressClassName is 'nginx'" \
    "kubectl get ingress rocket-ingress -n space \
       -o jsonpath='{.spec.ingressClassName}' 2>/dev/null | grep -q 'nginx'"

  end_task 12
}

# =============================================================================
# TASK 13 — RBAC: martin's Access
# =============================================================================
check_task13() {
  header "Task 13 — RBAC: martin's access (dev-a / dev-b / dev-z)"
  begin_task

  # dev-a: martin can do all pod operations
  check "martin has a RoleBinding in dev-a" \
    "kubectl get rolebindings -n dev-a 2>/dev/null | grep -q 'martin'"

  check "martin's role in dev-a allows all verbs on pods" \
    "kubectl auth can-i create pods -n dev-a --as=martin 2>/dev/null | grep -q 'yes'"

  check "martin can delete pods in dev-a" \
    "kubectl auth can-i delete pods -n dev-a --as=martin 2>/dev/null | grep -q 'yes'"

  # dev-b: martin can do all pod operations
  check "martin has a RoleBinding in dev-b" \
    "kubectl get rolebindings -n dev-b 2>/dev/null | grep -q 'martin'"

  check "martin's role in dev-b allows all verbs on pods" \
    "kubectl auth can-i create pods -n dev-b --as=martin 2>/dev/null | grep -q 'yes'"

  check "martin can delete pods in dev-b" \
    "kubectl auth can-i delete pods -n dev-b --as=martin 2>/dev/null | grep -q 'yes'"

  # dev-z: martin can ONLY get/list pods
  check "martin has a RoleBinding in dev-z" \
    "kubectl get rolebindings -n dev-z 2>/dev/null | grep -q 'martin'"

  check "martin can GET pods in dev-z" \
    "kubectl auth can-i get pods -n dev-z --as=martin 2>/dev/null | grep -q 'yes'"

  check "martin can LIST pods in dev-z" \
    "kubectl auth can-i list pods -n dev-z --as=martin 2>/dev/null | grep -q 'yes'"

  check "martin CANNOT create pods in dev-z (restricted)" \
    "kubectl auth can-i create pods -n dev-z --as=martin 2>/dev/null | grep -q 'no'"

  check "martin CANNOT delete pods in dev-z (restricted)" \
    "kubectl auth can-i delete pods -n dev-z --as=martin 2>/dev/null | grep -q 'no'"

  # Ensure no overly-permissive ClusterRoleBinding exists for martin
  check "martin has no ClusterRoleBinding granting cluster-wide access" \
    "! kubectl get clusterrolebindings 2>/dev/null \
       -o json | python3 -c \
       'import json,sys; d=json.load(sys.stdin); \
        items=[i for i in d[\"items\"] if any(s.get(\"name\")==\"martin\" for s in i[\"subjects\"])] \
        if \"items\" in d else []; sys.exit(0 if not items else 1)'"

  end_task 13
}

# =============================================================================
# TASK 14 — Audit Logging
# =============================================================================
check_task14() {
  header "Task 14 — Audit Logging (kube-apiserver)"
  begin_task

  # 1. Policy file exists
  check "Audit policy file exists at /etc/kubernetes/cluster-policy.yaml" \
    "[[ -f /etc/kubernetes/cluster-policy.yaml ]]"

  # 2. Policy has correct structure
  check "Audit policy contains 'RequestReceived' in omitStages" \
    "grep -q 'RequestReceived' /etc/kubernetes/cluster-policy.yaml 2>/dev/null"

  check "Audit policy has Metadata rule for secrets delete in kube-system" \
    "grep -q 'kube-system' /etc/kubernetes/cluster-policy.yaml 2>/dev/null"

  check "Audit policy has Request rule for deployments in default" \
    "grep -q 'default' /etc/kubernetes/cluster-policy.yaml 2>/dev/null"

  # 3. kube-apiserver flags
  check "kube-apiserver has --audit-policy-file flag" \
    "grep -q '\-\-audit-policy-file' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  check "kube-apiserver --audit-log-path points to /var/log/cluster-audit.log" \
    "grep -q 'cluster-audit.log' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  check "kube-apiserver --audit-log-maxage=10" \
    "grep -q '\-\-audit-log-maxage=10' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  check "kube-apiserver --audit-log-maxbackup=3" \
    "grep -q '\-\-audit-log-maxbackup=3' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  check "kube-apiserver --audit-log-maxsize=10" \
    "grep -q '\-\-audit-log-maxsize=10' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  # 4. Volume/mount for policy file in apiserver manifest
  check "kube-apiserver manifest has audit-policy volume defined" \
    "grep -q 'audit-policy' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  # 5. API server is running
  check "kube-apiserver pod is Running" \
    "kubectl get pods -n kube-system 2>/dev/null | grep kube-apiserver | grep -q Running"

  # 6. Audit log file created
  check "Audit log file /var/log/cluster-audit.log exists and is being written" \
    "[[ -f /var/log/cluster-audit.log ]]"

  end_task 14
}

# =============================================================================
# TASK 15 — ImagePolicyWebhook
# =============================================================================
check_task15() {
  header "Task 15 — ImagePolicyWebhook (block :latest)"
  begin_task

  # 1. Admission config file exists
  check "admission-configuration.yaml exists in /etc/admission-controllers/" \
    "[[ -f /etc/admission-controllers/admission-configuration.yaml ]] || \
     [[ -f /root/CKS/ImagePolicy/admission-configuration.yaml ]]"

  # 2. AdmissionConfiguration kind present
  check "Admission config is of kind AdmissionConfiguration" \
    "grep -q 'AdmissionConfiguration' \
       /etc/admission-controllers/admission-configuration.yaml 2>/dev/null || \
     grep -q 'AdmissionConfiguration' \
       /root/CKS/ImagePolicy/admission-configuration.yaml 2>/dev/null"

  # 3. defaultAllow: false
  check "defaultAllow is set to false (reject :latest at all times)" \
    "grep -q 'defaultAllow: false' \
       /etc/admission-controllers/admission-configuration.yaml 2>/dev/null || \
     grep -q 'defaultAllow: false' \
       /root/CKS/ImagePolicy/admission-configuration.yaml 2>/dev/null"

  # 4. kube-apiserver has ImagePolicyWebhook in enable-admission-plugins
  check "kube-apiserver enables ImagePolicyWebhook admission plugin" \
    "grep -q 'ImagePolicyWebhook' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  # 5. kube-apiserver has admission-control-config-file flag
  check "kube-apiserver has --admission-control-config-file flag" \
    "grep -q '\-\-admission-control-config-file' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  # 6. kube-apiserver is running
  check "kube-apiserver pod is Running" \
    "kubectl get pods -n kube-system 2>/dev/null | grep kube-apiserver | grep -q Running"

  # 7. app-0403 pod no longer uses :latest
  check "app-0403 pod does NOT use :latest image tag" \
    "! kubectl get pod app-0403 -n magnum \
        -o jsonpath='{.spec.containers[0].image}' 2>/dev/null \
        | grep -E ':latest$|[^:]+$' | grep -qv ':[0-9]'"

  # Rewritten: check the image tag is explicitly :1.27
  check "app-0403 pod image uses tag :1.27" \
    "kubectl get pod app-0403 -n magnum \
       -o jsonpath='{.spec.containers[0].image}' 2>/dev/null | grep -q ':1.27'"

  # 8. app-0403 pod is running
  check "app-0403 pod is Running" \
    "pod_running magnum app-0403"

  # 9. Reject a :latest pod (live webhook test)
  check "Webhook rejects a new pod with :latest image tag" \
    '! kubectl run test-latest-$$  --image=nginx:latest -n magnum \
        --dry-run=server 2>&1 | grep -q "allowed"'

  end_task 15
}

# =============================================================================
# SUMMARY TABLE
# =============================================================================
print_summary() {
  echo ""
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║                VERIFICATION SUMMARY                     ║${RESET}"
  echo -e "${BOLD}${CYAN}╠══════════════╦════════════╦═══════════════════════════╣${RESET}"
  printf "${BOLD}${CYAN}║  %-12s║  %-10s║  %-25s║${RESET}\n" "Task" "Status" "Checks (P/F/S)"
  echo -e "${BOLD}${CYAN}╠══════════════╬════════════╬═══════════════════════════╣${RESET}"

  for i in $(seq 1 15); do
    if [[ -n "${TASK_RESULTS[$i]+x}" ]]; then
      local res="${TASK_RESULTS[$i]}"
      local fails
      fails=$(echo "$res" | grep -oP '\d+(?=F)' || echo 0)
      if [[ "$fails" == "0" ]]; then
        status="${GREEN}PASS${RESET}"
      else
        status="${RED}FAIL${RESET}"
      fi
      printf "${CYAN}║${RESET}  Task %-7s${CYAN}║${RESET}  %-21b${CYAN}║${RESET}  %-25s${CYAN}║${RESET}\n" \
        "$i" "$status" "$res"
    fi
  done

  echo -e "${BOLD}${CYAN}╠══════════════╩════════════╩═══════════════════════════╣${RESET}"

  local pct=0
  if [[ $TOTAL -gt 0 ]]; then
    pct=$(( PASSED * 100 / TOTAL ))
  fi

  printf "${BOLD}${CYAN}║${RESET}  Total checks : %-3s   ${GREEN}Passed${RESET}: %-3s  ${RED}Failed${RESET}: %-3s  ${YELLOW}Skip${RESET}: %-3s  ${BOLD}${CYAN}║${RESET}\n" \
    "$TOTAL" "$PASSED" "$FAILED" "$SKIPPED"
  printf "${BOLD}${CYAN}║${RESET}  Score        : %s%%%-47s${BOLD}${CYAN}║${RESET}\n" "$pct" " "
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  if [[ $FAILED -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All checks passed! Great work. 🎉${RESET}"
  else
    echo -e "  ${RED}${BOLD}${FAILED} check(s) failed.${RESET} Review the ${RED}✘ FAIL${RESET} lines above."
    echo -e "  Tip: re-run with ${CYAN}--verbose${RESET} to see command output for failed checks."
  fi
  echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║       CKS Exam — Answer Verification Script         ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  [[ $(id -u) -eq 0 ]] || { echo -e "${RED}Run as root (sudo -i)${RESET}" >&2; exit 1; }
  command -v kubectl &>/dev/null || { echo -e "${RED}kubectl not found${RESET}" >&2; exit 1; }

  declare -A TASK_FN=(
    [1]=check_task1   [2]=check_task2   [3]=check_task3
    [4]=check_task4   [5]=check_task5   [6]=check_task6
    [7]=check_task7   [8]=check_task8   [9]=check_task9
    [10]=check_task10 [11]=check_task11 [12]=check_task12
    [13]=check_task13 [14]=check_task14 [15]=check_task15
  )

  if [[ "$TASK" == "all" ]]; then
    for i in $(seq 1 15); do ${TASK_FN[$i]}; done
  elif [[ -n "${TASK_FN[$TASK]+x}" ]]; then
    ${TASK_FN[$TASK]}
  else
    echo -e "${RED}Invalid task '$TASK'. Use 1-15 or 'all'.${RESET}" >&2; exit 1
  fi

  print_summary
}

main "$@"