#!/usr/bin/env bash
# =============================================================================
# CKS Exam Environment Setup Script
# Target : kubeadm cluster (Ubuntu 22.04 / 24.04), controlplane node
# Run as : root  (sudo -i first)
# Usage  : bash cks-exam-setup.sh [--task <1-15|all>] [--dry-run]
# =============================================================================
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${CYAN}  $*${RESET}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
TASK="all"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --task)  TASK="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) die "Unknown argument: $1. Usage: $0 [--task <1-15|all>] [--dry-run]" ;;
  esac
done

run() {
  if $DRY_RUN; then
    echo -e "  ${YELLOW}[dry-run]${RESET} $*"
  else
    eval "$@"
  fi
}

# ── Pre-flight checks ────────────────────────────────────────────────────────
preflight() {
  header "Pre-flight checks"
  [[ $(id -u) -eq 0 ]] || die "Must run as root. Use: sudo -i"
  command -v kubectl  &>/dev/null || die "kubectl not found"
  command -v kubeadm  &>/dev/null || die "kubeadm not found"
  kubectl cluster-info &>/dev/null || die "Cluster unreachable. Is kubeconfig set?"
  success "Cluster reachable"
  mkdir -p /root/CKS/secrets /root/CKS/ImagePolicy /root/ImageTarballs \
           /opt/course /opt/security_incidents /opt/kube-bench \
           /var/lib/kubelet/seccomp/profiles /etc/admission-controllers \
           /root/backup /data/pages/internal
  success "Base directories created"
}

# ── Backup kube-apiserver manifest ───────────────────────────────────────────
backup_apiserver() {
  if [[ ! -f /root/backup/kube-apiserver.yaml ]]; then
    cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/backup/kube-apiserver.yaml
    success "kube-apiserver.yaml backed up to /root/backup/"
  else
    info "Backup already exists, skipping."
  fi
}

# =============================================================================
# TASK 1 — AppArmor + Least-Privilege SA (omni namespace)
# =============================================================================
setup_task1() {
  header "Task 1 — AppArmor + Least-Privilege SA (omni namespace)"

  # 1a. Namespace + host data directory
  run kubectl create namespace omni --dry-run=client -o yaml | kubectl apply -f -
  run mkdir -p /data/pages/internal
  run 'echo "<h1>Public Page</h1>" > /data/pages/index.html'
  run 'echo "<h1>Internal - Confidential</h1>" > /data/pages/internal/index.html'
  success "Host directories and pages created"

  # 1b. AppArmor profile
  run cat > /etc/apparmor.d/frontend << 'APPARMOR'
#include <tunables/global>

profile restricted-frontend flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  network inet tcp,
  network inet udp,

  capability net_bind_service,

  # Allow nginx to operate
  /usr/sbin/nginx                  mr,
  /etc/nginx/**                    r,
  /var/log/nginx/**                rw,
  /var/run/nginx.pid               rw,
  /tmp/**                          rw,

  # Allow public web content
  /data/pages/                     r,
  /data/pages/index.html           r,

  # DENY internal directory
  deny /data/pages/internal/**     r,
  deny /usr/share/nginx/html/internal/** r,

  # Proc/sys access
  /proc/*/status                   r,
  /sys/kernel/mm/transparent_hugepage/hpage_pmd_size r,
}
APPARMOR
  success "AppArmor profile written to /etc/apparmor.d/frontend"

  # 1c. Load profile
  run apparmor_parser -q /etc/apparmor.d/frontend
  success "AppArmor profile 'restricted-frontend' loaded"

  # 1d. Service accounts
  run kubectl create serviceaccount frontend-default -n omni --dry-run=client -o yaml | kubectl apply -f -
  run kubectl create serviceaccount frontend -n omni --dry-run=client -o yaml | kubectl apply -f -
  run kubectl create serviceaccount fe -n omni --dry-run=client -o yaml | kubectl apply -f -

  # Give 'frontend' and 'fe' extra permissions so they are "more privileged"
  run kubectl create role frontend-role -n omni \
    --verb=get,list,watch,create,delete \
    --resource=pods,secrets --dry-run=client -o yaml | kubectl apply -f -
  run kubectl create rolebinding frontend-rb -n omni \
    --role=frontend-role --serviceaccount=omni:frontend \
    --dry-run=client -o yaml | kubectl apply -f -
  run kubectl create rolebinding fe-rb -n omni \
    --role=frontend-role --serviceaccount=omni:fe \
    --dry-run=client -o yaml | kubectl apply -f -
  success "Service accounts created (frontend, fe with extra perms; frontend-default with least)"

  # 1e. Deploy the misconfigured pod (no AppArmor, wrong SA) — the "broken" state
  run kubectl apply -f - << 'POD'
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: nginx
  name: frontend-site
  namespace: omni
spec:
  serviceAccountName: frontend
  containers:
  - image: nginx:alpine
    name: nginx
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      path: /data/pages
      type: Directory
POD
  success "Task 1 environment ready (broken pod deployed — fix it as per the task)"
}

# =============================================================================
# TASK 2 — Secrets as Mounted Volume (orion namespace)
# =============================================================================
setup_task2() {
  header "Task 2 — Secrets as Environment Variable (orion namespace)"

  run kubectl create namespace orion --dry-run=client -o yaml | kubectl apply -f -

  # Create the secret
  run kubectl create secret generic connector-credentials \
    --from-literal=CONNECTOR_PASSWORD='S3cur3P@ssw0rd!' \
    -n orion --dry-run=client -o yaml | kubectl apply -f -
  success "Secret 'connector-credentials' created in orion"

  # Deploy pod using secret as env var (the broken state)
  run kubectl apply -f - << 'POD'
apiVersion: v1
kind: Pod
metadata:
  name: connector-pod
  namespace: orion
spec:
  containers:
  - name: connector
    image: busybox:1.35
    command: ["sh", "-c", "env && sleep 3600"]
    env:
    - name: CONNECTOR_PASSWORD
      valueFrom:
        secretKeyRef:
          name: connector-credentials
          key: CONNECTOR_PASSWORD
POD
  run mkdir -p /root/CKS/secrets
  success "Task 2 environment ready (pod uses secret as env var — remount as volume)"
}

# =============================================================================
# TASK 3 — Static Analysis: Credential Exposure (/opt/course/)
# =============================================================================
setup_task3() {
  header "Task 3 — Static Analysis: Credential Exposure (/opt/course/)"

  run mkdir -p /opt/course

  # --- File WITH credentials (Dockerfile) ---
  run cat > /opt/course/Dockerfile.backend << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY . .
ENV DB_PASSWORD=SuperSecret123
ENV API_KEY=ghp_abcdefghijklmnopqrstuvwxyz1234567890
RUN npm install
EXPOSE 3000
CMD ["node", "server.js"]
EOF

  # --- File WITH credentials (YAML manifest) ---
  run cat > /opt/course/deployment-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: myrepo/backend:latest
        env:
        - name: DB_PASSWORD
          value: "PlainTextPassword99"
        - name: AWS_SECRET_ACCESS_KEY
          value: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
EOF

  # --- File WITHOUT credentials (clean Dockerfile) ---
  run cat > /opt/course/Dockerfile.frontend << 'EOF'
FROM nginx:alpine
COPY ./dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

  # --- File WITHOUT credentials (clean manifest) ---
  run cat > /opt/course/configmap-safe.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
EOF

  # --- File WITH credentials (ConfigMap used as secret store — wrong pattern) ---
  run cat > /opt/course/configmap-bad.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: default
data:
  DB_HOST: "postgres.internal"
  DB_USER: "admin"
  DB_PASSWORD: "hardcoded-db-pass-123"
EOF

  success "Task 3 environment ready — /opt/course/ populated with sample files"
  info "Files with issues: Dockerfile.backend, deployment-app.yaml, configmap-bad.yaml"
}

# =============================================================================
# TASK 4 — Seccomp Audit Profile for audit-nginx Pod
# =============================================================================
setup_task4() {
  header "Task 4 — Seccomp Audit Profile"

  run mkdir -p /root/CKS /var/lib/kubelet/seccomp/profiles

  run cat > /root/CKS/audit.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_LOG",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": [
        "accept4","brk","capget","capset","chdir","clone","close",
        "connect","dup2","epoll_create1","epoll_ctl","epoll_wait",
        "execve","exit_group","fchown","fcntl","fstat","futex",
        "getcwd","getdents64","getegid","geteuid","getgid","getpid",
        "getrandom","getuid","ioctl","listen","lstat","mmap",
        "mprotect","munmap","nanosleep","newfstatat","open","openat",
        "prctl","read","recvfrom","recvmsg","rt_sigaction",
        "rt_sigprocmask","rt_sigreturn","sendmsg","sendto",
        "set_robust_list","set_tid_address","setgid","setgroups",
        "setuid","socket","stat","uname","wait4","write","writev"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF
  success "audit.json written to /root/CKS/audit.json"
  info "Task: move it to /var/lib/kubelet/seccomp/profiles/ and create the pod"
}

# =============================================================================
# TASK 5 — CIS Benchmark Fixes (kubelet, etcd, control plane)
# =============================================================================
setup_task5() {
  header "Task 5 — CIS Benchmark: Introduce deliberate misconfigurations"

  # Intentionally widen permissions so kube-bench FАILs them
  run chmod 644 /usr/lib/systemd/system/kubelet.service  2>/dev/null || true
  run chmod 644 /var/lib/kubelet/config.yaml             2>/dev/null || true
  success "Kubelet file permissions widened to 644 (should be 600)"

  # etcd ownership — set to root so chown fix is needed
  run chown -R root:root /var/lib/etcd 2>/dev/null || true
  success "etcd directory ownership set to root:root (should be etcd:etcd)"

  # Remove --profiling=false from controller-manager and scheduler if present
  for manifest in /etc/kubernetes/manifests/kube-controller-manager.yaml \
                  /etc/kubernetes/manifests/kube-scheduler.yaml; do
    if [[ -f "$manifest" ]]; then
      run sed -i '/--profiling=false/d' "$manifest"
      success "Removed --profiling=false from $(basename $manifest)"
    fi
  done

  # Install kube-bench if not present
  if ! command -v kube-bench &>/dev/null; then
    info "Installing kube-bench..."
    KB_VER="0.8.0"
    run curl -sL "https://github.com/aquasecurity/kube-bench/releases/download/v${KB_VER}/kube-bench_${KB_VER}_linux_amd64.tar.gz" \
      | tar -xz -C /usr/local/bin kube-bench
    success "kube-bench installed"
  else
    success "kube-bench already installed"
  fi

  run mkdir -p /opt/kube-bench
  if [[ ! -d /opt/kube-bench/cfg ]]; then
    KB_VER="0.8.0"
    run curl -sL "https://github.com/aquasecurity/kube-bench/releases/download/v${KB_VER}/kube-bench_${KB_VER}_linux_amd64.tar.gz" \
      | tar -xz -C /opt/kube-bench cfg
    success "kube-bench cfg directory extracted to /opt/kube-bench/cfg"
  else
    info "kube-bench cfg already present"
  fi

  success "Task 5 environment ready — run kube-bench to identify and fix FAILs"
}

# =============================================================================
# TASK 6 — Falco: Override Rule with CRITICAL Priority
# =============================================================================
setup_task6() {
  header "Task 6 — Falco: Suspicious httpd pod + rule override"

  # Install Falco if not present
  if ! command -v falco &>/dev/null; then
    info "Installing Falco..."
    run curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
      | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
    run 'echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
      > /etc/apt/sources.list.d/falcosecurity.list'
    run apt-get update -qq
    run DEBIAN_FRONTEND=noninteractive apt-get install -y falco
    success "Falco installed"
  else
    success "Falco already installed"
  fi

  run mkdir -p /opt/security_incidents

  # Touch the local rules file so it exists
  run touch /etc/falco/falco_rules.local.yaml

  # Deploy the suspicious httpd pod that triggers the rule
  run kubectl create namespace falco-test --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
  run kubectl apply -f - << 'POD'
apiVersion: v1
kind: Pod
metadata:
  name: suspicious-httpd
  namespace: falco-test
spec:
  containers:
  - name: httpd
    image: httpd:2.4-alpine
    command: ["sh", "-c", "while true; do tar -cf /dev/null /bin/sh 2>/dev/null; sleep 5; done"]
    securityContext:
      allowPrivilegeEscalation: false
POD
  success "Task 6 environment ready"
  info "Edit /etc/falco/falco.yaml and /etc/falco/falco_rules.local.yaml to complete the task"
}

# =============================================================================
# TASK 7 — SBOM SPDX: fruits Deployment in salad namespace
# =============================================================================
setup_task7() {
  header "Task 7 — SBOM SPDX: fruits deployment (salad namespace)"

  run kubectl create namespace salad --dry-run=client -o yaml | kubectl apply -f -

  # Install bom (SPDX generator) if missing
  if ! command -v bom &>/dev/null; then
    info "Installing bom..."
    BOM_VER="v0.6.0"
    run curl -sL "https://github.com/kubernetes-sigs/bom/releases/download/${BOM_VER}/bom-amd64-linux" \
      -o /usr/local/bin/bom
    run chmod +x /usr/local/bin/bom
    success "bom installed"
  else
    success "bom already installed"
  fi

  # fruits deployment — kiwi has curl
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fruits
  namespace: salad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fruits
  template:
    metadata:
      labels:
        app: fruits
    spec:
      containers:
      - name: apple
        image: alpine:3.18
        command: ["sh", "-c", "sleep 3600"]
      - name: banana
        image: alpine:3.17
        command: ["sh", "-c", "sleep 3600"]
      - name: kiwi
        image: alpine:3.16
        command: ["sh", "-c", "apk add --no-cache curl -q && sleep 3600"]
DEPLOY
  success "fruits deployment created in salad namespace (kiwi container has curl)"

  # Pre-pull and save image tarballs
  run mkdir -p /root/ImageTarballs
  for img in alpine:3.16 alpine:3.17 alpine:3.18; do
    tarname=$(echo "$img" | tr ':/' '-')
    if [[ ! -f "/root/ImageTarballs/${tarname}.tar" ]]; then
      info "Saving ${img} tarball..."
      run docker pull "$img" -q 2>/dev/null || \
        run crictl pull "$img" 2>/dev/null || \
        warn "Could not pull ${img} — save tarball manually"
      run docker save "$img" -o "/root/ImageTarballs/${tarname}.tar" 2>/dev/null || \
        warn "docker save failed for ${img} — save manually"
    fi
  done
  success "Task 7 environment ready — check kiwi for curl, generate SBOM from tarball"
}

# =============================================================================
# TASK 8 — Service Account with Projected Token (automated namespace)
# =============================================================================
setup_task8() {
  header "Task 8 — SA with Projected Token (automated namespace)"

  run kubectl create namespace automated --dry-run=client -o yaml | kubectl apply -f -

  # sweeper deployment without bot-sa (broken state)
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sweeper
  namespace: automated
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sweeper
  template:
    metadata:
      labels:
        app: sweeper
    spec:
      containers:
      - name: sweeper
        image: busybox:1.35
        command: ["sh", "-c", "sleep 3600"]
DEPLOY
  success "Task 8 environment ready — create bot-sa and update sweeper deployment"
}

# =============================================================================
# TASK 9 — Fix Non-Running web-server (restricted namespace)
# =============================================================================
setup_task9() {
  header "Task 9 — Non-Running web-server (restricted namespace)"

  # Apply restricted PSA label to namespace
  run kubectl create namespace restricted --dry-run=client -o yaml | kubectl apply -f -
  run kubectl label namespace restricted \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest \
    --overwrite

  # Deploy web-server WITHOUT required security context — will be rejected/fail
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: restricted
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        # Missing: securityContext with runAsNonRoot, readOnlyRootFilesystem,
        #          allowPrivilegeEscalation: false, seccompProfile
DEPLOY
  success "Task 9 environment ready — fix the deployment so it satisfies restricted PSA"
  info "Hint: add securityContext with allowPrivilegeEscalation: false, runAsNonRoot: true,"
  info "      readOnlyRootFilesystem: true, seccompProfile.type: RuntimeDefault"
}

# =============================================================================
# TASK 10 — Network Policy: product-db → web-app + payments
# =============================================================================
setup_task10() {
  header "Task 10 — Network Policy (products / database / payments)"

  for ns in products database payments; do
    run kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  done

  # web-app in products
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: products
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web-app
        image: nginx:alpine
DEPLOY

  # product-db in database
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-db
  namespace: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: testpassword
DEPLOY

  # dummy workload in payments to verify allow-all traffic
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-app
  namespace: payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
      - name: payments
        image: busybox:1.35
        command: ["sh", "-c", "sleep 3600"]
DEPLOY
  success "Task 10 environment ready — create the NetworkPolicy to complete the task"
}

# =============================================================================
# TASK 11 — Security Context: gamma Deployment (galaxy namespace)
# =============================================================================
setup_task11() {
  header "Task 11 — Security Context: gamma (galaxy namespace)"

  run kubectl create namespace galaxy --dry-run=client -o yaml | kubectl apply -f -

  # gamma deployment WITHOUT security context (broken state)
  run kubectl apply -f - << 'DEPLOY'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gamma
  namespace: galaxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gamma
  template:
    metadata:
      labels:
        app: gamma
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
      - name: sidecar
        image: busybox:1.35
        command: ["sh", "-c", "sleep 3600"]
DEPLOY
  success "Task 11 environment ready — add securityContext to all containers"
}

# =============================================================================
# TASK 12 — Ingress with TLS: rocket-server (space namespace)
# =============================================================================
setup_task12() {
  header "Task 12 — TLS Ingress: rocket-server (space namespace)"

  run kubectl create namespace space --dry-run=client -o yaml | kubectl apply -f -

  # Generate self-signed TLS cert for rocket-server.local
  run openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/rocket.key -out /tmp/rocket.crt \
    -subj "/CN=rocket-server.local/O=CKS-Exam" \
    -addext "subjectAltName=DNS:rocket-server.local" 2>/dev/null
  run kubectl create secret tls rocket-tls \
    --cert=/tmp/rocket.crt --key=/tmp/rocket.key \
    -n space --dry-run=client -o yaml | kubectl apply -f -
  success "TLS secret 'rocket-tls' created in space namespace"

  # rocket-server deployment + service
  run kubectl apply -f - << 'MANIFEST'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rocket-server
  namespace: space
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocket-server
  template:
    metadata:
      labels:
        app: rocket-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: rocket-server
  namespace: space
spec:
  selector:
    app: rocket-server
  ports:
  - port: 80
    targetPort: 80
MANIFEST

  # Install nginx ingress controller if not present
  if ! kubectl get ns ingress-nginx &>/dev/null; then
    info "Installing nginx ingress controller..."
    run kubectl apply -f \
      https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/baremetal/deploy.yaml
    run kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s
    success "nginx ingress controller installed"
  else
    success "nginx ingress controller already present"
  fi

  success "Task 12 environment ready — create the Ingress resource to complete the task"
}

# =============================================================================
# TASK 13 — RBAC: martin's Overly Permissive Access
# =============================================================================
setup_task13() {
  header "Task 13 — RBAC: martin's access (dev-a / dev-b / dev-z)"

  for ns in dev-a dev-b dev-z; do
    run kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  done

  # Overly permissive setup — martin can do everything in all three namespaces
  for ns in dev-a dev-b dev-z; do
    run kubectl create role pod-admin -n "$ns" \
      --verb='*' --resource='*' \
      --dry-run=client -o yaml | kubectl apply -f -
    run kubectl create rolebinding martin-pod-admin -n "$ns" \
      --role=pod-admin --user=martin \
      --dry-run=client -o yaml | kubectl apply -f -
  done

  success "Task 13 environment ready — restrict martin's access as per requirements"
  info "dev-a, dev-b: all pod ops | dev-z: get,list pods only"
}

# =============================================================================
# TASK 14 — Audit Logging: kube-apiserver
# =============================================================================
setup_task14() {
  header "Task 14 — Audit Logging"

  # Create a minimal placeholder policy so the file exists
  run cat > /etc/kubernetes/cluster-policy.yaml << 'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- "RequestReceived"
rules:
- level: None
EOF
  success "Placeholder audit policy created at /etc/kubernetes/cluster-policy.yaml"
  info "Update the policy and kube-apiserver.yaml to complete the task"

  run mkdir -p /var/log
  run touch /var/log/cluster-audit.log
  success "Log file pre-created at /var/log/cluster-audit.log"
}

# =============================================================================
# TASK 15 — ImagePolicyWebhook: Block :latest Tag
# =============================================================================
setup_task15() {
  header "Task 15 — ImagePolicyWebhook (block :latest)"

  run mkdir -p /root/CKS/ImagePolicy /etc/admission-controllers

  # Deploy the image-bouncer-webhook
  run kubectl apply -f - << 'MANIFEST'
apiVersion: v1
kind: Namespace
metadata:
  name: image-bouncer-webhook
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-bouncer-webhook
  namespace: image-bouncer-webhook
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-bouncer-webhook
  template:
    metadata:
      labels:
        app: image-bouncer-webhook
    spec:
      containers:
      - name: image-bouncer-webhook
        image: kainlite/kube-image-bouncer:latest
        args:
        - --cert=/etc/admission-webhook/tls/tls.crt
        - --key=/etc/admission-webhook/tls/tls.key
        - --debug
        - --reject-latest
        ports:
        - containerPort: 1323
        volumeMounts:
        - name: tls
          mountPath: /etc/admission-webhook/tls
      volumes:
      - name: tls
        secret:
          secretName: image-bouncer-webhook-tls
---
apiVersion: v1
kind: Service
metadata:
  name: image-bouncer-webhook
  namespace: image-bouncer-webhook
spec:
  selector:
    app: image-bouncer-webhook
  ports:
  - port: 443
    targetPort: 1323
MANIFEST

  # Generate TLS cert for the webhook
  run openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/webhook.key -out /tmp/webhook.crt \
    -subj "/CN=image-bouncer-webhook.image-bouncer-webhook.svc" \
    -addext "subjectAltName=DNS:image-bouncer-webhook.image-bouncer-webhook.svc" 2>/dev/null
  run kubectl create secret tls image-bouncer-webhook-tls \
    --cert=/tmp/webhook.crt --key=/tmp/webhook.key \
    -n image-bouncer-webhook --dry-run=client -o yaml | kubectl apply -f -

  # Build the admission kubeconfig
  WEBHOOK_CA=$(base64 -w0 /tmp/webhook.crt 2>/dev/null || base64 /tmp/webhook.crt | tr -d '\n')
  run cat > /root/CKS/ImagePolicy/admission-kubeconfig.yaml << KUBECONFIG
apiVersion: v1
kind: Config
clusters:
- name: bouncer-webhook
  cluster:
    certificate-authority-data: ${WEBHOOK_CA}
    server: https://image-bouncer-webhook.image-bouncer-webhook.svc:443/image_policy
users:
- name: apiserver
  user: {}
contexts:
- name: bouncer-validator
  context:
    cluster: bouncer-webhook
    user: apiserver
current-context: bouncer-validator
KUBECONFIG
  success "admission-kubeconfig.yaml written to /root/CKS/ImagePolicy/"

  # Create the violating pod in magnum
  run kubectl create namespace magnum --dry-run=client -o yaml | kubectl apply -f -
  run kubectl apply -f - << 'POD'
apiVersion: v1
kind: Pod
metadata:
  name: app-0403
  namespace: magnum
spec:
  containers:
  - name: busybox
    image: gcr.io/google-containers/busybox
    command: ["sh", "-c", "sleep 3600"]
POD
  success "Violating pod app-0403 deployed in magnum namespace (uses :latest implicitly)"
  info "Create admission-configuration.yaml, enable ImagePolicyWebhook, then fix app-0403 to :1.27"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║       CKS Exam Environment Setup Script              ║"
  echo "║       Tasks 1-15 on a kubeadm cluster                ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  if $DRY_RUN; then
    warn "DRY-RUN mode — no changes will be made"
  fi

  preflight
  backup_apiserver

  declare -A TASK_MAP=(
    [1]=setup_task1   [2]=setup_task2   [3]=setup_task3
    [4]=setup_task4   [5]=setup_task5   [6]=setup_task6
    [7]=setup_task7   [8]=setup_task8   [9]=setup_task9
    [10]=setup_task10 [11]=setup_task11 [12]=setup_task12
    [13]=setup_task13 [14]=setup_task14 [15]=setup_task15
  )

  if [[ "$TASK" == "all" ]]; then
    for i in $(seq 1 15); do
      ${TASK_MAP[$i]}
    done
  elif [[ -n "${TASK_MAP[$TASK]+x}" ]]; then
    ${TASK_MAP[$TASK]}
  else
    die "Invalid task '$TASK'. Choose 1-15 or 'all'."
  fi

  echo ""
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
  echo -e "${BOLD}${GREEN}  Setup complete!${RESET}"
  echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${CYAN}Useful commands:${RESET}"
  echo -e "  kubectl get pods -A                        # overview"
  echo -e "  kubectl get ns                             # all namespaces"
  echo -e "  aa-status | grep restricted-frontend       # task 1 AA profile"
  echo -e "  kube-bench --benchmark cis-1.10 ...        # task 5"
  echo -e "  systemctl status falco                     # task 6"
  echo ""
  if $DRY_RUN; then
    warn "DRY-RUN: no changes were applied."
  fi
}

main "$@"