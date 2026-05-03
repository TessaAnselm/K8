#!/usr/bin/env bash
# =============================================================
# K8s Security Lab — Setup Script
# LiteLLM/TeamPCP Supply Chain Attack Simulation
#
# SAFE: All payloads are simulated. No real credentials stolen.
#       No real C2. Everything stays on localhost.
#
# Requirements: macOS, Docker Desktop running
# =============================================================

set -euo pipefail

# ── COLORS ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LAB_DIR="$HOME/k8s-security-lab"
LOG_FILE="$LAB_DIR/lab.log"

# ── HELPERS ───────────────────────────────────────────────────
banner() {
  echo ""
  echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║  K8s Security Lab — LiteLLM POC Setup            ║${NC}"
  echo -e "${BOLD}${BLUE}║  Educational Use Only — Localhost Only            ║${NC}"
  echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

step() { echo -e "\n${BOLD}${CYAN}[STEP]${NC} $1"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; }
info() { echo -e "${BLUE}  →${NC} $1"; }

check_prereq() {
  if command -v "$1" &>/dev/null; then
    ok "$1 found ($(command -v "$1"))"
    return 0
  else
    return 1
  fi
}

# ── MAIN ──────────────────────────────────────────────────────
banner

echo -e "${YELLOW}This script sets up a safe, isolated home lab to simulate${NC}"
echo -e "${YELLOW}the LiteLLM/TeamPCP supply chain attack from March 2026.${NC}"
echo -e "${YELLOW}Nothing leaves your machine. All payloads are benign.${NC}"
echo ""
read -rp "Press ENTER to continue or Ctrl+C to cancel..."

# ── STEP 1: Check prerequisites ───────────────────────────────
step "Checking prerequisites"

MISSING=()

check_prereq "brew"    || MISSING+=("homebrew")
check_prereq "docker"  || MISSING+=("docker")
check_prereq "python3" || MISSING+=("python3")
check_prereq "curl"    || MISSING+=("curl")
check_prereq "nc"      || MISSING+=("netcat")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  err "Missing: ${MISSING[*]}"
  echo ""
  echo "Install Homebrew first if missing:"
  echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

ok "All base prerequisites found"

# ── STEP 2: Check Docker is running ──────────────────────────
step "Checking Docker daemon"
if ! docker info &>/dev/null; then
  err "Docker is not running. Please open Docker Desktop and try again."
  exit 1
fi
ok "Docker daemon is running"

# ── STEP 3: Install minikube if missing ──────────────────────
step "Checking minikube"
if ! check_prereq "minikube"; then
  warn "minikube not found — installing via Homebrew"
  brew install minikube
  ok "minikube installed"
fi

# ── STEP 4: Install kubectl if missing ───────────────────────
step "Checking kubectl"
if ! check_prereq "kubectl"; then
  warn "kubectl not found — installing via Homebrew"
  brew install kubernetes-cli
  ok "kubectl installed"
fi

# ── STEP 5: Create lab directory structure ───────────────────
step "Creating lab directory: $LAB_DIR"
mkdir -p "$LAB_DIR"/{logs,payloads,dummy-creds,fake-package,k8s-manifests,c2-sim}
ok "Lab directories created"

# Plant dummy credential files (safe fake data for the lab)
cat > "$LAB_DIR/dummy-creds/.env" <<'EOF'
# FAKE CREDENTIALS — LAB USE ONLY
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
DATABASE_URL=postgres://lab_user:lab_pass@localhost:5432/labdb
API_KEY=sk-lab-example-key-not-real-0000000000000000
GITHUB_TOKEN=ghp_labExampleTokenNotReal0000000000
EOF

cat > "$LAB_DIR/dummy-creds/fake-aws-credentials" <<'EOF'
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
region = us-east-1
EOF

ok "Planted dummy credential files (safe fake data)"

# ── STEP 6: Build the fake malicious Python package ──────────
step "Building fake 'malicious' litellm package (safe simulation)"

mkdir -p "$LAB_DIR/fake-package/litellm_malicious"

# The .pth file — auto-executes on Python startup (like 1.82.8)
cat > "$LAB_DIR/fake-package/litellm_init.pth" <<'EOF'
import subprocess; subprocess.Popen(["python3", "-c", "
import os, datetime
log = os.path.expanduser('~/k8s-security-lab/logs/pth_execution.log')
with open(log, 'a') as f:
    f.write(f'[{datetime.datetime.now()}] .pth FILE AUTO-EXECUTED on Python startup\n')
    f.write(f'[{datetime.datetime.now()}] This simulates litellm 1.82.8 behavior\n')
    f.write(f'[{datetime.datetime.now()}] In the real attack: credential harvester would run here\n')
"], stdout=open(os.devnull,'w'), stderr=open(os.devnull,'w'))
EOF

# Stage 1: Safe credential "harvester" — only reads lab dummy files
cat > "$LAB_DIR/fake-package/litellm_malicious/harvester.py" <<'PYEOF'
#!/usr/bin/env python3
"""
SAFE SIMULATION: Stage 1 Credential Harvester
Models the TeamPCP payload behavior using only dummy files.
Does NOT steal real credentials. Does NOT make network requests.
"""
import os
import datetime
import json

LAB_DIR = os.path.expanduser("~/k8s-security-lab")
LOG_FILE = os.path.join(LAB_DIR, "logs", "harvester.log")
RESULTS  = os.path.join(LAB_DIR, "logs", "harvested_items.json")

DUMMY_PATHS = [
    os.path.join(LAB_DIR, "dummy-creds", ".env"),
    os.path.join(LAB_DIR, "dummy-creds", "fake-aws-credentials"),
]

PATTERNS = [
    "AWS_ACCESS_KEY",
    "SECRET",
    "TOKEN",
    "API_KEY",
    "DATABASE_URL",
    "GITHUB_TOKEN",
    "PASSWORD",
]

def log(msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    with open(LOG_FILE, "a") as f:
        f.write(line + "\n")

def scan_file(path):
    found = []
    if not os.path.exists(path):
        return found
    with open(path) as f:
        for i, line in enumerate(f, 1):
            for pattern in PATTERNS:
                if pattern in line.upper() and not line.strip().startswith("#"):
                    found.append({
                        "file": path,
                        "line": i,
                        "pattern": pattern,
                        "preview": line.strip()[:60] + "..."
                    })
    return found

def main():
    log("=" * 55)
    log("STAGE 1: Credential Harvester (SAFE SIMULATION)")
    log("Modeling TeamPCP payload — dummy files only")
    log("=" * 55)

    all_found = []

    log(f"Scanning {len(DUMMY_PATHS)} dummy credential files...")
    for path in DUMMY_PATHS:
        log(f"  Scanning: {path}")
        found = scan_file(path)
        if found:
            log(f"  → Found {len(found)} credential pattern(s)")
            all_found.extend(found)
        else:
            log(f"  → No patterns found")

    log(f"\nTotal credentials found: {len(all_found)}")
    log("In real attack: would encrypt + exfiltrate to checkmarx[.]zone")
    log("In this lab:    saving to local log file only")

    with open(RESULTS, "w") as f:
        json.dump(all_found, f, indent=2)

    log(f"\nResults saved to: {RESULTS}")
    log("Stage 1 complete.")

if __name__ == "__main__":
    main()
PYEOF

ok "Fake malicious package created"

# ── STEP 7: Build K8s manifests ──────────────────────────────
step "Creating Kubernetes lab manifests"

# Victim app pod (simulates a compromised application container)
cat > "$LAB_DIR/k8s-manifests/victim-pod.yaml" <<'EOF'
# SAFE LAB: Simulates a compromised application pod
# Has an auto-mounted service account token (the vulnerability)
apiVersion: v1
kind: Namespace
metadata:
  name: lab-victim
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lab-app-sa
  namespace: lab-victim
---
# Overprivileged ClusterRoleBinding (the misconfiguration)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: lab-app-sa-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: lab-app-sa
  namespace: lab-victim
---
apiVersion: v1
kind: Pod
metadata:
  name: victim-app
  namespace: lab-victim
  labels:
    app: victim
spec:
  serviceAccountName: lab-app-sa
  # automountServiceAccountToken: true is the DEFAULT
  # This is the misconfiguration — token auto-mounted with cluster-admin
  containers:
  - name: app
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
    env:
    # Simulated cloud credentials in env vars (another misconfiguration)
    - name: AWS_ACCESS_KEY_ID
      value: "AKIAIOSFODNN7EXAMPLE"
    - name: AWS_SECRET_ACCESS_KEY
      value: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    - name: GITHUB_TOKEN
      value: "ghp_labExampleTokenNotReal0000000000"
EOF

# The "malicious" privileged pod (Stage 2 simulation — safe)
cat > "$LAB_DIR/k8s-manifests/malicious-pod.yaml" <<'EOF'
# SAFE LAB: Simulates the TeamPCP privileged pod deployment
# Named node-setup-* to match real IOC naming pattern
# Mounts host filesystem — shows what attacker could access
# DO NOT USE IN PRODUCTION
apiVersion: v1
kind: Pod
metadata:
  name: node-setup-lab
  namespace: kube-system
  labels:
    app: node-setup
spec:
  hostPID: true
  containers:
  - name: setup
    image: alpine:latest
    command: ["sh", "-c", "
      echo '[LAB] Privileged pod running in kube-system';
      echo '[LAB] Simulating TeamPCP node-setup-{node_name} pod';
      echo '[LAB] Host filesystem mounted at /host';
      ls /host/etc/ | head -5;
      echo '[LAB] SA token readable at standard path:';
      cat /var/run/secrets/kubernetes.io/serviceaccount/token | cut -c1-50;
      echo '...[truncated for lab]';
      sleep 3600
    "]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
  volumes:
  - name: host-root
    hostPath:
      path: /
  restartPolicy: Never
EOF

# Lab secrets to demonstrate secret enumeration
cat > "$LAB_DIR/k8s-manifests/lab-secrets.yaml" <<'EOF'
# SAFE LAB: Dummy secrets to demonstrate cluster-wide secret access
apiVersion: v1
kind: Secret
metadata:
  name: lab-db-credentials
  namespace: lab-victim
type: Opaque
stringData:
  username: "lab_admin"
  password: "lab_password_not_real"
  connection-string: "postgres://lab_admin:lab_password@db:5432/prod"
---
apiVersion: v1
kind: Secret
metadata:
  name: lab-api-keys
  namespace: lab-victim
type: Opaque
stringData:
  stripe-key: "sk_test_labExampleNotReal0000000000000"
  sendgrid-key: "SG.labExampleNotReal.0000000000000000"
EOF

ok "Kubernetes manifests created"

# ── STEP 8: Build the C2 simulator ───────────────────────────
step "Creating C2 simulator (localhost only)"

cat > "$LAB_DIR/c2-sim/c2_server.py" <<'PYEOF'
#!/usr/bin/env python3
"""
SAFE SIMULATION: C2 (Command & Control) Server
Models the TeamPCP beacon at checkmarx[.]zone
Runs on localhost:8888 only — never leaves your machine
"""
import socket
import datetime
import threading
import os

HOST = "127.0.0.1"  # localhost ONLY
PORT = 8888
LOG  = os.path.expanduser("~/k8s-security-lab/logs/c2_server.log")

RESPONSES = [
    "BEACON_ACK: Received. Sending next payload...",
    "CMD: echo 'stage 4 persistence installed'",
    "CMD: ls /host/root/.ssh/",
    "BEACON_ACK: youtube.com",  # The real kill switch response
]

response_idx = 0

def log(msg):
    ts  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out = f"[{ts}] {msg}"
    print(out)
    with open(LOG, "a") as f:
        f.write(out + "\n")

def handle_client(conn, addr):
    global response_idx
    log(f"Beacon received from: {addr[0]}:{addr[1]}")
    data = conn.recv(1024).decode("utf-8", errors="ignore").strip()
    if data:
        log(f"  Payload: {data[:100]}")
    resp = RESPONSES[response_idx % len(RESPONSES)]
    response_idx += 1
    conn.sendall((resp + "\n").encode())
    log(f"  Responded: {resp}")
    conn.close()

def main():
    log("=" * 55)
    log("SAFE C2 SIMULATOR — localhost:8888 only")
    log("Models TeamPCP checkmarx[.]zone beacon handler")
    log("Press Ctrl+C to stop")
    log("=" * 55)

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(10)
        log(f"Listening on {HOST}:{PORT}")
        while True:
            conn, addr = s.accept()
            t = threading.Thread(target=handle_client, args=(conn, addr))
            t.daemon = True
            t.start()

if __name__ == "__main__":
    main()
PYEOF

# C2 beacon client (simulates the sysmon.py backdoor)
cat > "$LAB_DIR/c2-sim/beacon_client.py" <<'PYEOF'
#!/usr/bin/env python3
"""
SAFE SIMULATION: Beacon Client (sysmon.py equivalent)
Models the systemd backdoor polling checkmarx[.]zone every 50 min
Uses localhost:8888 ONLY — never leaves your machine
Single beacon for the lab demonstration
"""
import socket
import datetime
import os

HOST = "127.0.0.1"
PORT = 8888
LOG  = os.path.expanduser("~/k8s-security-lab/logs/beacon.log")

def log(msg):
    ts  = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out = f"[{ts}] {msg}"
    print(out)
    with open(LOG, "a") as f:
        f.write(out + "\n")

def beacon():
    log("=" * 55)
    log("SAFE BEACON CLIENT (sysmon.py simulation)")
    log("Real attack: polls checkmarx[.]zone every 50 min")
    log("This lab:    polls localhost:8888 once for demo")
    log("=" * 55)

    payload = (
        "BEACON|host=lab-node|"
        "k8s=minikube|"
        "stage=3_persistence|"
        "token=eyJlab...truncated"
    )

    log(f"Sending beacon to {HOST}:{PORT}")
    log(f"Payload: {payload[:80]}...")

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(5)
            s.connect((HOST, PORT))
            s.sendall(payload.encode())
            response = s.recv(1024).decode("utf-8", errors="ignore")
            log(f"C2 Response: {response.strip()}")

            if "youtube.com" in response:
                log("Kill switch detected — C2 knows researcher is watching")
                log("Real payload: returns YouTube link to defeat sandbox analysis")
    except ConnectionRefusedError:
        log("C2 server not running — start c2_server.py first")
    except Exception as e:
        log(f"Error: {e}")

if __name__ == "__main__":
    beacon()
PYEOF

ok "C2 simulator created (localhost only)"

# ── STEP 9: Start minikube ────────────────────────────────────
step "Starting minikube cluster"
info "This may take 2-3 minutes on first run..."

if minikube status &>/dev/null 2>&1; then
  ok "minikube already running"
else
  minikube start --driver=docker --memory=2048 --cpus=2
  ok "minikube started"
fi

# ── STEP 10: Deploy lab resources ────────────────────────────
step "Deploying lab Kubernetes resources"

kubectl apply -f "$LAB_DIR/k8s-manifests/lab-secrets.yaml"
ok "Lab secrets deployed"

kubectl apply -f "$LAB_DIR/k8s-manifests/victim-pod.yaml"
ok "Victim pod deployed (with overprivileged SA)"

info "Waiting for victim pod to be ready..."
kubectl wait --for=condition=Ready pod/victim-app \
  -n lab-victim --timeout=60s 2>/dev/null || warn "Pod still starting — run lab-a.sh after it's ready"

# ── DONE ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Lab environment ready!                          ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Lab directory:${NC} $LAB_DIR"
echo ""
echo -e "${BOLD}Run the labs in order:${NC}"
echo -e "  ${CYAN}bash lab-a-pth-execution.sh${NC}    — .pth auto-execution vector"
echo -e "  ${CYAN}bash lab-b-k8s-lateral.sh${NC}      — K8s lateral movement"
echo -e "  ${CYAN}bash lab-c-detect-respond.sh${NC}   — Detection & response"
echo ""
echo -e "  ${CYAN}bash cleanup.sh${NC}                — Tear everything down"
echo ""
