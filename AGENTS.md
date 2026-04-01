# AGENTS.md — AI Assistant Reference

Quick reference for AI assistants (Claude, Gemini, etc.) working in this repo.

## Stack

- **K3s** — Lightweight Kubernetes on two Mac Mini M4s
- **Lima** — Linux VMs on macOS (Apple virtualization framework)
- **Ansible** — Infrastructure automation (playbooks 01–09, run in order)
- **socket_vmnet** — Bridged VM networking
- **Thunderbolt** — Direct high-speed link between Mac Minis

## Key Paths

| Path | Purpose |
|------|---------|
| `ansible/inventory/hosts.ini` | Host definitions (IPs in `host_vars/`, gitignored) |
| `ansible/host_vars/*.yml.example` | IP templates — copy to `*.yml` and fill in |
| `ansible/group_vars/mac_minis.yml` | Shared vars (user, key, limactl path, subnets) |
| `ansible/playbooks/01–09` | Sequential setup playbooks |
| `lima/k3s-master.yaml` | Master VM config (2 CPU, 4 GB, Ubuntu 22.04 ARM64) |
| `lima/k3s-worker.yaml` | Worker VM config |
| `kubernetes/apps/` | Helm-based app deployments, one dir per phase |

## Ansible

```bash
# Run any playbook
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/<name>.yml

# Playbook 06 needs sudo password
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/06-setup-nat-forwarding.yml -K

# Test connectivity
ansible -i ansible/inventory/hosts.ini mac_minis -m ping
```

`limactl` must use its full path (`/opt/homebrew/bin/limactl`) in non-interactive SSH sessions — already set in `group_vars`.

## Lima VMs

```bash
limactl start --name=k3s-master ~/k3s-master.yaml
limactl shell k3s-master
limactl list
limactl stop k3s-master
```

## K3s

```bash
# From macmini-01
limactl shell k3s-master -- sudo k3s kubectl get nodes
limactl shell k3s-master -- sudo k3s kubectl get pods -A
limactl shell k3s-master -- sudo cat /var/lib/rancher/k3s/server/node-token
```

Master has NoSchedule taint removed — workloads run on both nodes.

## Network

Three subnets (exact IPs are in `ansible/host_vars/`, gitignored):
- Management LAN — Ansible SSH access
- Thunderbolt bridge — Inter-node K3s traffic
- Lima vzNAT — Internal VM network

VMs route to the Thunderbolt bridge and internet via pf NAT rules on each Mac host (`/etc/pf.anchors/lima.nat`). The anchor must be referenced in `/etc/pf.conf` after `nat-anchor "com.apple/*"`.

## Secrets

- `ansible/host_vars/*.yml` — gitignored, real IPs
- `kubernetes/apps/security-data/manifests/tenzir-secret.yaml` — gitignored, Tenzir API token
- `kubernetes/apps/security-data/.env.example` — template, copy to `.env`

## Kubernetes Phases

| Phase | Namespace | Status |
|-------|-----------|--------|
| 1 — Monitoring | `monitoring` | Complete |
| 2 — Telemetry | `telemetry` | Complete |
| 3 — Security Data | `security-data` | In Progress |
| 4 — Vuln Lab | `vuln-lab` | In Progress |
| 5 — Zero Trust | `zero-trust` | Planned |

Each phase has its own `deploy.yml` and `status.yml` in `kubernetes/apps/<phase>/`.
