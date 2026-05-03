/* ============================================================
   DATA/CVES.JS — Single source of truth for all CVE data
   K8s Security Lab

   To add a new CVE: add an entry to the CVES array.
   The page renders from this data automatically.
============================================================ */

const CVES = [
  {
    id:       'launch-2014',
    year:     2014,
    sev:      'launch',
    mitre:    '',
    dotColor: 'var(--ok)',
    badge:    'Launch',
    title:    'Google open-sources Kubernetes',
    desc:     'Released at DockerCon. Built internally as "Project Seven" (a Star Trek reference). No CVEs yet — very few organizations running it in production.',
    cves:     [],
    detect: {
      intro: 'Nothing to detect — this is the baseline.',
      body:  'When K8s launched, the attack surface was minimal and largely unknown. The lesson: security awareness did not keep pace with adoption speed.',
      cols:  []
    }
  },

  {
    id:       'cve-2016',
    year:     2016,
    sev:      'critical',
    mitre:    'TA0004',
    dotColor: 'var(--danger)',
    badge:    'CVSS 10.0',
    title:    'First CVE — Perfect Worst Score',
    desc:     'CVE-2016-1906: OpenShift (K8s-based) allowed remote attackers to gain full privileges by updating a build config type. First K8s CVE, maximum severity.',
    cves:     ['CVE-2016-1906', 'CVE-2016-1905'],
    detect: {
      intro: 'CVE-2016-1906 — Check cluster version and RBAC build config permissions.',
      cols: [
        {
          label: 'Version check',
          code:  `<span class="c">kubectl</span> version <span class="f">--short</span>\n<span class="cm"># Affected: OpenShift &lt; 3.1.1</span>\n<span class="c">oc</span> version`
        },
        {
          label: 'RBAC audit',
          code:  `<span class="c">kubectl</span> auth can-i update buildconfigs\n<span class="c">kubectl</span> get clusterrolebindings <span class="f">-o wide</span>`
        }
      ],
      mitreTag: ['TA0004 — Privilege Escalation', 'T1078 — Valid Accounts']
    }
  },

  {
    id:       'cve-2018',
    year:     2018,
    sev:      'critical',
    mitre:    'TA0004 TA0001',
    dotColor: null,
    badge:    'Critical',
    title:    'CVE-2018-1002105 — API Server Privilege Escalation',
    desc:     'A critical flaw allowing any user to escalate to full cluster-admin via a crafted API request. One of the most serious early K8s CVEs. K8s adoption explodes — more users, more scrutiny, more bugs found.',
    cves:     ['CVE-2017-1002101', 'CVE-2018-1002105'],
    detect: {
      cols: [
        {
          label: 'Version check',
          code:  `<span class="cm"># Vulnerable: &lt; 1.10.11, 1.11.5, 1.12.3</span>\n<span class="c">kubectl</span> version <span class="f">--short</span>\n\n<span class="cm"># Test anonymous access — should return 401</span>\n<span class="c">curl</span> <span class="f">-k</span> https://&lt;api-server&gt;:6443/api/v1`
        },
        {
          label: 'Anonymous auth check',
          code:  `<span class="c">kubectl</span> get pod kube-apiserver-* \\\n  <span class="f">-n</span> kube-system <span class="f">-o yaml</span> \\\n  <span class="f">| grep</span> anonymous-auth\n<span class="cm"># Should be: --anonymous-auth=false</span>`
        }
      ],
      mitreTag: ['TA0004 — Privilege Escalation', 'T1190 — Exploit Public App']
    }
  },

  {
    id:       'cve-2020',
    year:     2020,
    sev:      'high',
    mitre:    'TA0006',
    dotColor: null,
    badge:    'High',
    title:    'CVE-2020-8555 — Secrets Leak in Logs',
    desc:     'Ceph RBD admin secrets leaked into kube-controller-manager logs at log level 4+. Steady cadence of ~10-20 CVEs/year. Focus on SA privilege, API server logic flaws, secrets in logs.',
    cves:     ['CVE-2019-9512', 'CVE-2020-8555', 'CVE-2021-25735'],
    detect: {
      cols: [
        {
          label: 'Check log verbosity',
          code:  `<span class="c">kubectl</span> get pod kube-controller-manager-* \\\n  <span class="f">-n</span> kube-system <span class="f">-o yaml | grep</span> v=\n<span class="cm"># Vulnerable if v=4 or higher</span>`
        },
        {
          label: 'Search logs for exposure',
          code:  `<span class="c">kubectl</span> logs kube-controller-manager-* \\\n  <span class="f">-n</span> kube-system \\\n  <span class="f">| grep -i</span> "secret\\|password\\|token"\n<span class="cm"># Fix: set --v=2 maximum</span>`
        }
      ],
      mitreTag: ['TA0006 — Credential Access', 'T1552 — Unsecured Credentials']
    }
  },

  {
    id:       'cve-2023',
    year:     2023,
    sev:      'critical',
    mitre:    'TA0001 TA0004 TA0040',
    dotColor: 'var(--danger)',
    badge:    'Spike',
    title:    'Windows Nodes, nginx Injection, HTTP/2 DDoS',
    desc:     'Major Windows node privilege escalation cluster (3 CVEs). nginx ingress annotation injection → cluster-admin. HTTP/2 Rapid Reset DDoS takes down ingress controllers globally. ServiceAccount token projection bypass.',
    cves:     ['CVE-2023-5528', 'CVE-2023-5043', 'CVE-2023-44487', 'CVE-2023-2728'],
    detect: {
      cols: [
        {
          label: 'CVE-2023-44487: Ingress version',
          code:  `<span class="c">kubectl</span> get pods <span class="f">-n</span> ingress-nginx \\\n  <span class="f">-o json | jq</span> \\\n  '.items[].spec.containers[].image'\n<span class="cm"># Must be >= nginx-ingress 1.9.4</span>`
        },
        {
          label: 'CVE-2023-5528: Windows PVCs',
          code:  `<span class="c">kubectl</span> get pv <span class="f">-o json | jq</span> \\\n  '.items[] | select(.spec.hostPath)\n  | .metadata.name'\n<span class="cm"># Remove hostPath PVs on Windows nodes</span>`
        }
      ],
      mitreTag: ['TA0001 — Initial Access', 'TA0004 — Privilege Escalation', 'TA0040 — Impact']
    }
  },

  {
    id:       'cve-2024',
    year:     2024,
    sev:      'critical',
    mitre:    'TA0004 TA0001 TA0008',
    dotColor: 'var(--danger)',
    badge:    'Critical',
    title:    'Leaky Vessels, nftables Kernel Escape, nginx cluster-admin',
    desc:     'runc "Leaky Vessels" (CVE-2024-21626) — container escape via file descriptor leak, affects Docker/containerd/CRI-O. Linux kernel nftables use-after-free exploitable from containers. nginx ingress annotation bypass → cluster-admin (CVE-2024-7646).',
    cves:     ['CVE-2024-21626', 'CVE-2024-0193', 'CVE-2024-7646', 'CVE-2024-3177'],
    detect: {
      cols: [
        {
          label: 'CVE-2024-21626: runc version',
          code:  `<span class="c">runc</span> <span class="f">--version</span>\n<span class="cm"># Vulnerable: &lt; 1.1.12</span>\n<span class="c">docker</span> info <span class="f">| grep -i</span> runc\n<span class="c">trivy</span> image <span class="f">--severity CRITICAL</span> myimage`
        },
        {
          label: 'CVE-2024-0193 + CVE-2024-7646',
          code:  `<span class="c">uname</span> <span class="f">-r</span>\n<span class="cm"># Vulnerable: &lt; 6.6.7</span>\n\n<span class="c">kubectl</span> get ingress <span class="f">-A -o json | jq</span> \\\n  '.items[].metadata.annotations\n  | to_entries[] | select(.key\n  | contains("snippet"))'`
        }
      ],
      mitreTag: ['TA0004 — Privilege Escalation', 'T1611 — Escape to Host', 'TA0008 — Lateral Movement']
    }
  },

  {
    id:       'cve-2026',
    year:     2026,
    sev:      'supply',
    mitre:    'TA0001 TA0006 TA0003 TA0008',
    dotColor: 'var(--purple)',
    badge:    'Supply Chain Era',
    title:    'AI Tooling Becomes the Attack Surface',
    desc:     'IngressNightmare (CVE-2025-1974) — unauthenticated RCE, 43% of cloud environments vulnerable. React2Shell exploited within 2 days. LiteLLM supply chain attack (March 2026) — TeamPCP compromises Trivy → KICS → LiteLLM (3.4M downloads/day), full K8s cluster takeover.',
    cves:     ['CVE-2025-1974', 'CVE-2025-55182', 'CVE-2026-33634', 'SNYK-2026-001357'],
    detect: {
      cols: [
        {
          label: 'LiteLLM: Check for compromised version',
          code:  `<span class="c">pip</span> show litellm <span class="f">| grep</span> Version\n<span class="cm"># Compromised: 1.82.7 or 1.82.8</span>\n\n<span class="c">find</span> ~/.cache/uv <span class="f">-name</span> "litellm_init.pth"`
        },
        {
          label: 'Check for backdoor + malicious pods',
          code:  `<span class="c">systemctl</span> <span class="f">--user status</span> sysmon.service\n<span class="c">ls</span> ~/.config/sysmon/sysmon.py\n<span class="c">kubectl</span> get pods <span class="f">-A | grep</span> node-setup\n\n<span class="cm"># CVE-2025-1974: Ingress version</span>\n<span class="c">kubectl</span> get pods <span class="f">-n</span> ingress-nginx \\\n  <span class="f">-o jsonpath</span>='{.items[*].spec.containers[*].image}'`
        }
      ],
      mitreTag: ['TA0001 — Initial Access', 'T1195 — Supply Chain', 'TA0003 — Persistence', 'TA0008 — Lateral Movement']
    }
  }
];
