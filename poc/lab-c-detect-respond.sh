#!/usr/bin/env bash
# =============================================================
# Lab C — Detection & Response
# Practice running every detection command from the site
# against your lab cluster. See what attackers leave behind.
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

LAB_DIR="$HOME/k8s-security-lab"
REPORT="$LAB_DIR/logs/detection_report.txt"

step()    { echo -e "\n${BOLD}${CYAN}━━ DETECT $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BOLD}$2${NC}"; }
found()   { echo -e "${RED}  🔴 FOUND:${NC} $1"; }
clean()   { echo -e "${GREEN}  🟢 CLEAN:${NC} $1"; }
cmd()     { echo -e "\n${BLUE}  \$${NC} ${BOLD}$*${NC}"; }
explain() { echo -e "${YELLOW}  📖${NC} $1"; }

log_report() {
  echo "$1" >> "$REPORT"
}

clear
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗"
echo -e "║  Lab C: Detection & Response                     ║"
echo -e "║  Hunting for TeamPCP IOCs in your lab cluster    ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "This lab runs all detection commands from the site"
echo "against your live minikube cluster. The compromised"
echo "state from Lab B is still present — let's find it."
echo ""

# Initialize report
{
  echo "K8s Security Lab — Detection Report"
  echo "Generated: $(date)"
  echo "Cluster: $(kubectl config current-context 2>/dev/null)"
  echo "======================================"
} > "$REPORT"

read -rp "Press ENTER to start hunting..."

# ── DETECT 1: Compromised Python packages ─────────────────────
step "1" "Check for compromised LiteLLM versions"
explain "First thing to check after the LiteLLM incident."

cmd "pip show litellm 2>/dev/null | grep Version"
echo ""
VERSION=$(pip show litellm 2>/dev/null | grep Version | awk '{print $2}' || echo "not installed")
echo "  litellm version: $VERSION"

if [[ "$VERSION" == "1.82.7" || "$VERSION" == "1.82.8" ]]; then
  found "COMPROMISED VERSION DETECTED: $VERSION"
  log_report "CRITICAL: Compromised litellm $VERSION found"
else
  clean "litellm $VERSION (not a compromised version)"
  log_report "OK: litellm version $VERSION is safe"
fi

echo ""
cmd "find ~/.cache/uv -name 'litellm_init.pth' 2>/dev/null"
PTH=$(find ~/.cache/uv -name 'litellm_init.pth' 2>/dev/null | head -3)
if [[ -n "$PTH" ]]; then
  found "Malicious .pth file found in cache: $PTH"
  log_report "CRITICAL: litellm_init.pth found at $PTH"
else
  clean "No litellm_init.pth in uv cache"
fi

# Check our lab venv
cmd "find $LAB_DIR -name '*.pth' | xargs grep -l subprocess 2>/dev/null"
LAB_PTH=$(find "$LAB_DIR" -name "*.pth" 2>/dev/null | \
  xargs grep -l subprocess 2>/dev/null | head -3 || true)
if [[ -n "$LAB_PTH" ]]; then
  found "Suspicious .pth file: $LAB_PTH"
  log_report "FOUND: Suspicious .pth with subprocess at $LAB_PTH"
fi

read -rp $'\nPress ENTER for next check...'

# ── DETECT 2: Persistence artifacts ──────────────────────────
step "2" "Check for backdoor persistence (sysmon.service)"
explain "The Stage 3 backdoor installs a systemd service."

cmd "ls -la ~/.config/sysmon/ 2>/dev/null"
if [[ -d "$HOME/.config/sysmon" ]]; then
  found "Backdoor directory exists: ~/.config/sysmon/"
  ls -la "$HOME/.config/sysmon/" 2>/dev/null
  log_report "CRITICAL: ~/.config/sysmon/ directory found"
else
  clean "No ~/.config/sysmon/ directory"
  log_report "OK: No sysmon backdoor directory"
fi

echo ""
cmd "launchctl list 2>/dev/null | grep sysmon"
SYSMON=$(launchctl list 2>/dev/null | grep -i sysmon || true)
if [[ -n "$SYSMON" ]]; then
  found "Sysmon service running: $SYSMON"
  log_report "CRITICAL: sysmon service active"
else
  clean "No sysmon service running"
fi

echo ""
cmd "ls /tmp/tpcp.tar.gz 2>/dev/null"
if [[ -f "/tmp/tpcp.tar.gz" ]]; then
  found "TeamPCP archive found: /tmp/tpcp.tar.gz"
  log_report "CRITICAL: /tmp/tpcp.tar.gz found (exfiltration archive)"
else
  clean "No /tmp/tpcp.tar.gz exfiltration archive"
fi

read -rp $'\nPress ENTER for next check...'

# ── DETECT 3: Malicious pods in kube-system ──────────────────
step "3" "Hunt for malicious pods in kube-system"
explain "The IOC: pods named node-setup-* in kube-system namespace."

cmd "kubectl get pods -n kube-system | grep node-setup"
echo ""
MALICIOUS_PODS=$(kubectl get pods -n kube-system 2>/dev/null | grep "node-setup" || true)
if [[ -n "$MALICIOUS_PODS" ]]; then
  found "Malicious pods found in kube-system:"
  echo "$MALICIOUS_PODS"
  log_report "CRITICAL: node-setup-* pods found in kube-system"
  log_report "$MALICIOUS_PODS"
else
  clean "No node-setup-* pods in kube-system"
fi

echo ""

# ── DETECT 4: Privileged pods anywhere ───────────────────────
step "4" "Find all privileged pods across the cluster"
explain "Any pod running with privileged: true is a high-severity finding."

cmd "kubectl get pods -A -o json | python3 -c \"...\""
echo ""
echo -e "${BOLD}Privileged pods found:${NC}"

kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
found = []
for item in data.get('items', []):
    ns   = item['metadata']['namespace']
    name = item['metadata']['name']
    for c in item['spec'].get('containers', []):
        sc = c.get('securityContext', {})
        if sc.get('privileged'):
            found.append(f'  namespace={ns}  pod={name}  container={c[\"name\"]}')
if found:
    for f in found: print(f)
else:
    print('  None found')
" 2>/dev/null || warn "Could not query pods"

log_report "Privileged pod check complete — see above"

read -rp $'\nPress ENTER for next check...'

# ── DETECT 5: Overprivileged service accounts ────────────────
step "5" "Check for overprivileged service accounts"
explain "The default SA should have no cluster-admin. Lab-app-sa does —
this is the misconfiguration that made the attack work."

cmd "kubectl get clusterrolebindings -o wide | grep -v system:"
echo ""
kubectl get clusterrolebindings -o wide 2>/dev/null | \
  grep -v "^system:" | grep -v "^NAME" | head -15 || true

echo ""
cmd "kubectl auth can-i --list --as=system:serviceaccount:lab-victim:lab-app-sa | grep secrets"
echo ""
echo -e "${BOLD}What lab-app-sa can do with secrets:${NC}"
CAN=$(kubectl auth can-i --list \
  --as=system:serviceaccount:lab-victim:lab-app-sa 2>/dev/null | \
  grep "secrets" | head -5 || true)
if [[ -n "$CAN" ]]; then
  found "Service account has secret access:"
  echo "$CAN"
  log_report "CRITICAL: lab-app-sa has cluster-wide secret access"
else
  clean "Service account has no secret access"
fi

read -rp $'\nPress ENTER for next check...'

# ── DETECT 6: Cloud credentials in env vars ──────────────────
step "6" "Find cloud credentials stored as environment variables"
explain "Any AWS/GCP/Azure keys in pod env vars is an instant finding."

cmd "kubectl get pods -A -o json | python3 -c '...find AWS/GCP/AZURE in env...'"
echo ""
echo -e "${BOLD}Cloud credentials exposed in pod environment:${NC}"

kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
PATTERNS = ['AWS', 'AZURE', 'GCP', 'TOKEN', 'SECRET', 'KEY', 'PASSWORD']
for item in data.get('items', []):
    ns   = item['metadata']['namespace']
    name = item['metadata']['name']
    for c in item['spec'].get('containers', []):
        for env in c.get('env', []):
            ename = env.get('name','').upper()
            if any(p in ename for p in PATTERNS):
                val = env.get('value','')
                print(f'  {ns}/{name}: {ename}={val[:20]}...')
" 2>/dev/null || warn "Could not enumerate env vars"

echo ""
log_report "Cloud credential env var check complete"

read -rp $'\nPress ENTER for next check...'

# ── DETECT 7: Network connections to C2 ──────────────────────
step "7" "Check for outbound C2 connections"
explain "The real attack beaconed to checkmarx[.]zone every 50 minutes.
Our lab C2 runs on localhost:8888."

cmd "netstat -an | grep -E '8888|checkmarx'"
echo ""
C2=$(netstat -an 2>/dev/null | grep -E "8888|checkmarx" || true)
if [[ -n "$C2" ]]; then
  found "C2 connection detected:"
  echo "$C2"
  log_report "CRITICAL: Active C2 connection found"
else
  clean "No active C2 connections (C2 simulator not running)"
  log_report "OK: No C2 connections"
fi

echo ""
cmd "lsof -i :8888 2>/dev/null"
lsof -i :8888 2>/dev/null || clean "Port 8888 not in use"

read -rp $'\nPress ENTER to see the full detection report...'

# ── FINAL REPORT ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}${PURPLE}━━ DETECTION REPORT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
cat "$REPORT"
echo ""
echo -e "${BOLD}Full report saved to:${NC} $REPORT"
echo ""

# ── REMEDIATION CHECKLIST ─────────────────────────────────────
echo -e "${BOLD}${CYAN}━━ REMEDIATION CHECKLIST ━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Delete node-setup-* pods from kube-system"
echo -e "    ${BLUE}\$ kubectl delete pod node-setup-lab -n kube-system${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Remove overprivileged ClusterRoleBinding"
echo -e "    ${BLUE}\$ kubectl delete clusterrolebinding lab-app-sa-admin${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Set automountServiceAccountToken: false"
echo -e "    ${BLUE}Edit victim-pod.yaml and re-apply${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Remove cloud credentials from env vars"
echo -e "    ${BLUE}Use Workload Identity or External Secrets Operator${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Rotate ALL credentials that were exposed"
echo -e "    ${BLUE}AWS keys, GitHub tokens, database passwords${NC}"
echo ""
echo -e "  ${YELLOW}□${NC} Upgrade litellm to >= 1.83.0"
echo -e "    ${BLUE}\$ pip install litellm==1.83.0${NC}"
echo ""
echo -e "${GREEN}${BOLD}Lab C complete! Run cleanup.sh when finished.${NC}"
echo ""
