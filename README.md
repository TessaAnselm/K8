# K8s Security Lab 🛡️

> An interactive reference covering real Kubernetes CVEs, the MITRE ATT&CK framework, hands-on lab modules, and a fully runnable POC simulation of the 2026 LiteLLM supply chain attack.

🔴 **Live site:** `https://TessaAnselm.github.io/K8`

---

> [!WARNING]
> **🚧 Work in Progress** — This project is actively being built. Content, lab scenarios, and POC scripts are being added and refined. Expect changes. Contributions and feedback welcome.

---

## What's Covered

### 📖 History & Context
- What Kubernetes is and why it's attacked
- The 3 root causes: Misconfiguration (53%), Code Bugs (38%), Supply Chain (9%)
- Full CVE timeline: 2014 → 2026 (90+ CVEs) — sortable, filterable, click to expand detection commands

### 🔴 Newest Attacks (2026 → 2024)
- **LiteLLM / Trivy / TeamPCP (March 2026)** — Featured case study
  - 3-hop supply chain: Trivy CI/CD → KICS → LiteLLM (3.4M downloads/day)
  - 3-stage payload: credential harvest → K8s lateral movement → persistent backdoor
  - Full MITRE ATT&CK mapping across 8+ techniques
  - Full IOC panel: package versions, file paths, C2 domains, K8s artifacts
- **IngressNightmare CVE-2025-1974** — Unauthenticated RCE, 43% of clouds vulnerable
- **React2Shell CVE-2025-55182** — Exploited within 2 days of disclosure
- **runc Leaky Vessels CVE-2024-21626** — Container escape via fd leak

### ⚗️ POC Home Lab — LiteLLM Simulation
Runnable bash scripts that simulate the full 3-stage attack on your local machine. Safe, isolated, localhost only.

| Script | What it simulates | Time |
|--------|------------------|------|
| `poc/setup.sh` | Installs minikube, builds lab environment, deploys victim pod | ~3 min |
| `poc/lab-a-pth-execution.sh` | .pth auto-execution — Stage 1 payload fires on Python startup | ~5 min |
| `poc/lab-b-k8s-lateral.sh` | Steal SA token, enumerate secrets, deploy privileged pod, mount host FS | ~10 min |
| `poc/lab-c-detect-respond.sh` | Hunt IOCs in live cluster, generate detection report, remediation checklist | ~5 min |
| `poc/cleanup.sh` | Removes all lab resources cleanly | ~1 min |

### 🎯 MITRE ATT&CK Framework
- Full tactic/technique mapping for containers (8 tactics)
- Click any tactic → highlights related CVEs in the timeline
- Every lab scenario tagged to ATT&CK techniques
- Covers TA0001 through TA0040

### 🔬 Lab Modules (3 Modules, 9 Scenarios)

| Module | MITRE Tactic | Scenarios |
|--------|-------------|-----------|
| **Module 1: Getting In** | TA0001 — Initial Access | Exposed API Server, Malicious Image, kubelet Read-Only Port |
| **Module 2: Breaking Out** | TA0004 — Privilege Escalation | runc CVE-2024-21626, Privileged Pod Escape, nftables CVE-2024-0193 |
| **Module 3: Taking Over** | TA0008 + TA0003 | nginx Annotation Injection, Overprivileged SA, Persistent Backdoor |

Each scenario: what it is → reproduce it → detect it → fix it. Progress tracked in browser.

### 🛡️ Defense Playbook
- Tools mapped to each attack stage (Trivy, Falco, kube-bench, OPA/Gatekeeper, Tetragon)
- Supply chain golden rules for 2026
- Network control, secrets management, admission control

---

## Interactive Features

- **Timeline sort** — newest/oldest toggle + filter by Critical / High / Supply Chain
- **Click-to-detect** — every timeline entry expands with terminal detection commands
- **MITRE highlighter** — click a tactic, related CVEs glow in the timeline
- **Copy buttons** — one click copies any command block
- **Lab progress tracker** — checkboxes per scenario, saves in browser localStorage
- **Global search** — searches across all CVEs, tools, and techniques

---

## Running the POC Lab (macOS)

> Requires: Docker Desktop running, macOS, bash

```bash
# 1. Clone the repo
git clone https://github.com/TessaAnselm/K8.git
cd K8/poc/

# 2. Run setup (installs minikube + kubectl if missing)
bash setup.sh

# 3. Run labs in order
bash lab-a-pth-execution.sh
bash lab-b-k8s-lateral.sh
bash lab-c-detect-respond.sh

# 4. Clean up everything when done
bash cleanup.sh
```

All lab files are created under `~/k8s-security-lab/` — nothing touches system directories.

---

## Project Structure

```
K8/
  index.html                  ← Single-page site (all sections)
  README.md                   ← This file
  assets/
    css/
      base.css                ← Tokens, reset, nav, shared components
      timeline.css            ← CVE timeline styles
      mitre.css               ← MITRE ATT&CK grid
      newest.css              ← Attack cards, chain, payload, IOC panel
      lab.css                 ← Lab modules, scenarios, progress, POC
      defense.css             ← Defense playbook
    js/
      copy.js                 ← Copy button logic
      timeline.js             ← Sort (newest/oldest), severity filter
      mitre.js                ← Tactic click → highlight CVEs
      lab.js                  ← Module tabs, scenario toggle, progress
      search.js               ← Global search with text highlighting
      nav.js                  ← Scroll-aware nav active state
    data/
      cves.js                 ← All CVE data (single source of truth)
  poc/
    setup.sh                  ← Install prereqs, build lab environment
    lab-a-pth-execution.sh    ← Stage 1: .pth auto-execution simulation
    lab-b-k8s-lateral.sh      ← Stage 2: K8s lateral movement simulation
    lab-c-detect-respond.sh   ← Stage 3: Detection & response
    cleanup.sh                ← Remove all lab resources
```

---

## Adding a New CVE

Edit `assets/data/cves.js` — add one object to the `CVES` array. The timeline renders it automatically. No HTML changes needed.

```javascript
{
  id:       'cve-2026-example',
  year:     2026,
  sev:      'critical',          // critical | high | medium | supply | launch
  mitre:    'TA0001 TA0004',     // space-separated tactic IDs
  badge:    'Critical',
  title:    'Your CVE Title',
  desc:     'Description of the vulnerability.',
  cves:     ['CVE-2026-00000'],
  detect: {
    cols: [
      { label: 'Tool name', code: 'your detection command here' }
    ],
    mitreTag: ['TA0001 — Initial Access']
  }
}
```

---

## Key CVEs Referenced

| CVE | CVSS | Component | Year |
|-----|------|-----------|------|
| CVE-2026-33634 | 9.4 | Trivy CI/CD (supply chain) | 2026 |
| CVE-2025-1974 | 9.8 | nginx Ingress (IngressNightmare) | 2025 |
| CVE-2025-55182 | Critical | React Server Components | 2025 |
| CVE-2024-21626 | Critical | runc (Leaky Vessels) | 2024 |
| CVE-2024-7646 | Critical | nginx Ingress annotation injection | 2024 |
| CVE-2024-0193 | Critical | Linux kernel nftables | 2024 |
| CVE-2024-3177 | Medium | K8s mountable secrets bypass | 2024 |
| CVE-2023-44487 | High | HTTP/2 Rapid Reset DDoS | 2023 |
| CVE-2023-5528 | High | Windows nodes PVC escalation | 2023 |
| CVE-2023-2728 | High | ServiceAccount token projection | 2023 |

---

## Roadmap 🚧

- [ ] Add more 2026 CVEs as they are disclosed
- [ ] Lab D — runc Leaky Vessels hands-on simulation
- [ ] Lab E — IngressNightmare POC
- [ ] Falco rules integration into Lab C
- [ ] Dark/light mode toggle
- [ ] Mobile nav improvements

---

## Disclaimer

This project is for **educational purposes only**. All POC scripts run in isolated local environments (minikube). All payloads are safe — no real credentials are stolen, no real network traffic leaves your machine. Never test these techniques against systems you do not own or have explicit permission to test.

---

## Resources

- [Kubernetes Official CVE Feed](https://kubernetes.io/docs/reference/issues-security/official-cve-feed/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [LiteLLM Supply Chain Incident](https://docs.litellm.ai/blog/security-update-march-2026)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Falco Rules](https://falco.org/docs/rules/)
- [kube-bench](https://github.com/aquasecurity/kube-bench)
- [Trivy](https://github.com/aquasecurity/trivy)