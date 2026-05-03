#!/usr/bin/env bash
# =============================================================
# K8s Security Lab — Cleanup Script
# Removes all lab resources safely
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

LAB_DIR="$HOME/k8s-security-lab"

ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }
step() { echo -e "\n${BOLD}${BLUE}[CLEANUP]${NC} $1"; }

echo ""
echo -e "${BOLD}${RED}K8s Security Lab — Cleanup${NC}"
echo -e "This will remove all lab resources from your cluster."
echo ""
read -rp "Press ENTER to continue or Ctrl+C to cancel..."

# ── K8s resources ─────────────────────────────────────────────
step "Removing malicious pod from kube-system"
kubectl delete pod node-setup-lab -n kube-system --ignore-not-found=true
ok "node-setup-lab removed"

step "Removing victim namespace and all resources"
kubectl delete namespace lab-victim --ignore-not-found=true
ok "lab-victim namespace removed"

step "Removing overprivileged ClusterRoleBinding"
kubectl delete clusterrolebinding lab-app-sa-admin --ignore-not-found=true
ok "ClusterRoleBinding removed"

# ── Python venv ───────────────────────────────────────────────
step "Removing lab Python virtual environment"
rm -rf "$LAB_DIR/venv-lab"
ok "venv-lab removed"

# ── .pth file from any site-packages ─────────────────────────
step "Removing any stray litellm_init.pth files"
find /usr /opt ~/.local "$HOME/Library" \
  -name "litellm_init.pth" 2>/dev/null | while read -r f; do
  rm -f "$f"
  ok "Removed: $f"
done || true

# ── Sysmon backdoor simulation artifacts ─────────────────────
step "Removing simulated backdoor artifacts"
rm -rf "$HOME/.config/sysmon" 2>/dev/null && ok "~/.config/sysmon removed" || true
rm -f /tmp/tpcp.tar.gz 2>/dev/null && ok "/tmp/tpcp.tar.gz removed" || true

# ── Logs — keep for reference ────────────────────────────────
step "Preserving lab logs for reference"
echo -e "  Logs kept at: ${BLUE}$LAB_DIR/logs/${NC}"
ls "$LAB_DIR/logs/" 2>/dev/null || true

# ── Optional: stop minikube ───────────────────────────────────
echo ""
read -rp "Stop minikube cluster too? (y/N): " STOP_MK
if [[ "${STOP_MK,,}" == "y" ]]; then
  minikube stop
  ok "minikube stopped"
else
  ok "minikube left running"
fi

echo ""
echo -e "${GREEN}${BOLD}Cleanup complete.${NC}"
echo -e "Lab logs are preserved at: ${BLUE}$LAB_DIR/logs/${NC}"
echo ""
