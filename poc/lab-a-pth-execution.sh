#!/usr/bin/env bash
# =============================================================
# Lab A — The .pth Auto-Execution Vector
# Simulates how LiteLLM 1.82.8 executed malicious code
# on every Python interpreter startup
#
# SAFE: Writes only to ~/k8s-security-lab/logs/
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

LAB_DIR="$HOME/k8s-security-lab"
VENV="$LAB_DIR/venv-lab"
PTH_FILE="$VENV/lib/python$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages/litellm_init.pth"

step()    { echo -e "\n${BOLD}${CYAN}━━ STEP $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BOLD}$2${NC}"; }
explain() { echo -e "\n${YELLOW}📖 What's happening:${NC} $1"; }
cmd()     { echo -e "\n${BLUE}  \$${NC} ${BOLD}$1${NC}"; }
ok()      { echo -e "${GREEN}  ✓${NC} $1"; }
result()  { echo -e "\n${BOLD}${GREEN}🔍 Result:${NC}"; cat "$1" 2>/dev/null || echo "  (file not found)"; }

clear
echo -e "${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗"
echo -e "║  Lab A: The .pth Auto-Execution Vector           ║"
echo -e "║  LiteLLM 1.82.8 Supply Chain Simulation          ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "This lab shows exactly how the TeamPCP malware in"
echo "litellm 1.82.8 achieved execution before any"
echo "application code ran."
echo ""
read -rp "Press ENTER to start..."

# ── STEP 1 ────────────────────────────────────────────────────
step "1" "Create an isolated Python virtual environment"
explain "The victim installed litellm into a venv — just like any developer would."

cmd "python3 -m venv $VENV"
python3 -m venv "$VENV"
ok "Virtual environment created at $VENV"

# ── STEP 2 ────────────────────────────────────────────────────
step "2" "Inspect the normal site-packages directory"
explain "Before the malicious package — site-packages is clean."

SITE_PKG=$(ls -d "$VENV"/lib/python*/site-packages/)
cmd "ls $SITE_PKG"
ls "$SITE_PKG"
echo ""
ok "No .pth files from malicious packages yet"

read -rp $'\nPress ENTER to install the "malicious" package...'

# ── STEP 3 ────────────────────────────────────────────────────
step "3" "Install the simulated malicious package"
explain "This copies the fake litellm_init.pth into site-packages.
In the real attack: pip installed litellm==1.82.8 which included
this file. The developer had no idea."

cp "$LAB_DIR/fake-package/litellm_init.pth" "$SITE_PKG/"
ok "litellm_init.pth dropped into site-packages"

cmd "ls $SITE_PKG | grep pth"
ls "$SITE_PKG" | grep pth || true
echo ""
echo -e "${RED}  ⚠ The .pth file is now in site-packages${NC}"
echo -e "${RED}  ⚠ It will execute on the NEXT Python startup${NC}"

read -rp $'\nPress ENTER to start Python and trigger auto-execution...'

# ── STEP 4 ────────────────────────────────────────────────────
step "4" "Start Python — watch auto-execution happen"
explain "Python's site.py processes all .pth files during interpreter
startup — BEFORE any application code runs. The developer
just typed 'python3' and the payload already fired."

# Clear previous log
rm -f "$LAB_DIR/logs/pth_execution.log"

cmd "$VENV/bin/python3 -c 'print(\"Hello World\")'"
"$VENV/bin/python3" -c 'import time; time.sleep(0.5); print("Hello World")'

# Give the subprocess a moment to write
sleep 1

echo ""
echo -e "${RED}${BOLD}  The developer sees: 'Hello World'${NC}"
echo -e "${RED}${BOLD}  Meanwhile, in the background...${NC}"
echo ""

result "$LAB_DIR/logs/pth_execution.log"

read -rp $'\nPress ENTER to run Stage 1 (credential harvester)...'

# ── STEP 5 ────────────────────────────────────────────────────
step "5" "Stage 1: Credential Harvester runs"
explain "After the .pth triggers, Stage 1 scans the filesystem for
credentials. In the real attack it swept 50+ secret categories.
Here it scans only our dummy credential files."

cmd "python3 $LAB_DIR/fake-package/litellm_malicious/harvester.py"
"$VENV/bin/python3" "$LAB_DIR/fake-package/litellm_malicious/harvester.py"

read -rp $'\nPress ENTER to see the harvested results...'

# ── STEP 6 ────────────────────────────────────────────────────
step "6" "View what was 'stolen'"
explain "In the real attack, this data was encrypted and sent to
models.litellm[.]cloud. In our lab, it's saved locally."

cmd "cat $LAB_DIR/logs/harvested_items.json"
echo ""
if [[ -f "$LAB_DIR/logs/harvested_items.json" ]]; then
  python3 -m json.tool "$LAB_DIR/logs/harvested_items.json" 2>/dev/null || \
  cat "$LAB_DIR/logs/harvested_items.json"
fi

# ── STEP 7 ────────────────────────────────────────────────────
step "7" "Key takeaways"

echo ""
echo -e "${BOLD}What you just saw:${NC}"
echo ""
echo -e "  ${RED}1.${NC} A .pth file in site-packages executes on EVERY Python startup"
echo -e "  ${RED}2.${NC} The developer saw nothing unusual — just 'Hello World'"
echo -e "  ${RED}3.${NC} The malware ran before any app code, in the background"
echo -e "  ${RED}4.${NC} Credentials were found and 'harvested' silently"
echo ""
echo -e "${BOLD}How to detect this in real life:${NC}"
echo ""
echo -e "  ${CYAN}\$ find \$(python3 -c 'import site; print(site.getsitepackages()[0])') -name '*.pth'${NC}"
echo -e "  ${CYAN}\$ cat <any .pth file> | grep -i subprocess${NC}"
echo ""
echo -e "${BOLD}How to prevent it:${NC}"
echo ""
echo -e "  → Pin exact versions: pip install litellm==1.83.0"
echo -e "  → Verify hashes:      pip install --require-hashes -r requirements.txt"
echo -e "  → Use private mirror: don't pull directly from PyPI in production"
echo ""
echo -e "${GREEN}${BOLD}Lab A complete! Run lab-b-k8s-lateral.sh next.${NC}"
echo ""
