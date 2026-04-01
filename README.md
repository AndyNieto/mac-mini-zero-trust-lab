# HomeLab — Dual Mac Mini M4 K3s Security Lab

A production-grade home lab built on two Mac Mini M4s connected via Thunderbolt, running a K3s Kubernetes cluster with a full security observability stack. Built to learn and demonstrate Zero Trust architecture, cloud-native security, and SIEM pipelines — all on personal hardware.

---

## Hardware

| Node | Role | Network | Thunderbolt |
|------|------|---------|-------------|
| macmini-01 | K3s Control Plane | 192.168.1.x | 192.168.20.x |
| macmini-02 | K3s Worker | 192.168.1.x | 192.168.20.x |

- **Total cost**: ~$1,048
- **Connection**: Direct Thunderbolt cable (high-speed, low-latency node-to-node link)
- **K3s nodes**: Linux VMs running inside [Lima](https://github.com/lima-vm/lima) on each Mac Mini (Ubuntu 22.04 ARM64, 2 CPU / 4 GB RAM / 30 GB disk each)

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      macmini-01                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          Lima VM: k3s-master (192.168.64.2)         │  │
│  │   Prometheus · Grafana · Loki · OTel · Jaeger       │  │
│  │   Tenzir · Fluent Bit · DVWA · Juice Shop           │  │
│  └─────────────────────────────────────────────────────┘  │
│  Host: 192.168.1.x  ←──Thunderbolt──→  192.168.20.x       │
└──────────────────────────────────────────────────────────┘
                           ║
                  Thunderbolt Bridge
                    192.168.20.0/24
                           ║
┌──────────────────────────────────────────────────────────┐
│                      macmini-02                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          Lima VM: k3s-worker (192.168.64.2)         │  │
│  │              Worker node workloads                   │  │
│  └─────────────────────────────────────────────────────┘  │
│  Host: 192.168.1.x  ←──Thunderbolt──→  192.168.20.x       │
└──────────────────────────────────────────────────────────┘
```

**Network layers:**
- `192.168.1.0/24` — Management LAN (Ansible SSH access)
- `192.168.20.0/24` — Thunderbolt bridge (inter-node K3s traffic)
- `192.168.64.0/24` — Lima vzNAT (VM internal network)

pf NAT rules on each host forward VM traffic over the Thunderbolt bridge and out to the internet.

---

## Stack Overview

| Phase | Status | Components |
|-------|--------|------------|
| 0 — Infrastructure | ✅ Complete | Ansible, Lima, socket_vmnet, K3s |
| 1 — Monitoring | ✅ Complete | Prometheus, Grafana, Alertmanager |
| 2 — Telemetry | ✅ Complete | Loki, Promtail, OpenTelemetry, Jaeger |
| 3 — Security Data | 🔄 In Progress | Tenzir, Fluent Bit, OCSF normalization |
| 4 — Vuln Lab | 🔄 In Progress | DVWA, Juice Shop, WebGoat, Kali |
| 5 — Zero Trust | ❌ Planned | Istio/Linkerd, OPA, SPIFFE/SPIRE |
| 6 — AI Security | ⏳ Future | NVIDIA Morpheus (requires GPU) |

---

## Security Data Pipeline

```
Pod Logs ──► Fluent Bit (DaemonSet)
                │
                ▼
             Tenzir
          (parse + enrich)
                │
                ▼
        OCSF Normalization
    (vendor-neutral schema)
                │
                ▼
      Tenzir Cloud / SIEM
```

All security events are normalized to [OCSF (Open Cybersecurity Schema Framework)](https://schema.ocsf.io/) — a vendor-neutral schema that eliminates field name inconsistencies across tools.

---

## Vulnerability Lab

Phase 4 deploys intentionally vulnerable applications in an isolated `vuln-lab` namespace for hands-on attack and detection practice:

- **DVWA** — Damn Vulnerable Web Application (OWASP Top 10)
- **OWASP Juice Shop** — Modern vulnerable Node.js app
- **WebGoat** — Interactive security training
- **Kali Linux** — Penetration testing toolkit

Network policies enforce namespace isolation — no egress to internet, no ingress from other namespaces.

Attacks against these targets are visible in the Phase 3 OCSF security data pipeline.

---

## Repository Structure

```
HomeLab/
├── ansible/
│   ├── inventory/hosts.ini         # Host definitions (IPs in host_vars/, gitignored)
│   ├── host_vars/*.yml.example     # IP placeholder templates — copy and fill in yours
│   ├── group_vars/mac_minis.yml    # Shared vars (user, key, network ranges)
│   └── playbooks/                  # 9 numbered setup playbooks + utilities
├── lima/
│   ├── k3s-master.yaml             # K3s master VM config
│   └── k3s-worker.yaml             # K3s worker VM config
├── kubernetes/
│   └── apps/
│       ├── monitoring/             # Phase 1: Prometheus stack
│       ├── telemetry/              # Phase 2: Loki + OTel + Jaeger
│       ├── security-data/          # Phase 3: Tenzir + Fluent Bit
│       ├── vuln-lab/               # Phase 4: Vulnerable targets
│       └── zero-trust/             # Phase 5: Service mesh (planned)
├── docs/
│   ├── CYBERSECURITY_LAB_PLAN.md   # 6-month learning roadmap
│   └── thunderbolt-k3s-setup.md   # Network + VM setup guide
├── CLAUDE.md                       # Architecture reference
└── observability_and_security_pipeline.md
```

---

## Getting Started

### Prerequisites

- Two Apple Silicon Mac Minis connected via Thunderbolt
- macOS with Homebrew installed
- SSH key at `~/.ssh/id_ed25519` with access to both hosts

### 1. Configure host variables

```bash
cp ansible/host_vars/macmini-01.yml.example ansible/host_vars/macmini-01.yml
cp ansible/host_vars/macmini-02.yml.example ansible/host_vars/macmini-02.yml
# Edit both files with your actual IPs
```

### 2. Run Ansible playbooks in order

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/01-install-lima.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/02-install-docker.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/03-install-socket-vmnet.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/04-setup-lima-networking.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/05-setup-launchd-service.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/06-setup-nat-forwarding.yml -K
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/07-copy-k3s-configs.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/08-install-k3s-master.yml
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/09-join-k3s-worker.yml
```

> Playbook 06 requires `-K` for the sudo password (pf NAT rules need root).

### 3. Deploy Kubernetes phases

Each phase has its own `deploy.yml` Ansible playbook:

```bash
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/monitoring/deploy.yml
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/telemetry/deploy.yml
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/security-data/deploy.yml
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/vuln-lab/deploy.yml
```

### 4. Configure Tenzir

Copy the secret template and fill in your token from [app.tenzir.com](https://app.tenzir.com):

```bash
cp kubernetes/apps/security-data/manifests/tenzir-secret.yaml.example \
   kubernetes/apps/security-data/manifests/tenzir-secret.yaml
# Edit and add your TENZIR_TOKEN
```

---

## Secrets Management

This repo uses a gitignore-based approach to keep secrets local:

| File | Status |
|------|--------|
| `ansible/host_vars/*.yml` | Gitignored — real IPs stay local |
| `ansible/host_vars/*.yml.example` | Published — copy and fill in your IPs |
| `kubernetes/apps/security-data/manifests/tenzir-secret.yaml` | Gitignored — Tenzir API token stays local |
| `kubernetes/apps/security-data/.env.example` | Published — shows required env vars |

---

## Access

After deployment, services are accessible via SSH tunnel from your workstation:

| Service | NodePort | Tunnel command |
|---------|----------|----------------|
| Grafana | 30300 | `ssh -L 3000:localhost:30300 homelab@<master-ip>` |
| Jaeger UI | 30686 | `ssh -L 16686:localhost:30686 homelab@<master-ip>` |
| DVWA | 30880 | `ssh -L 8080:localhost:30880 homelab@<master-ip>` |

---

## Docs

- [Architecture reference](CLAUDE.md)
- [Network + VM setup guide](docs/thunderbolt-k3s-setup.md)
- [Security data pipeline design](observability_and_security_pipeline.md)
- [6-month learning roadmap](docs/CYBERSECURITY_LAB_PLAN.md)
