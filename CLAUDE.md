# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Infrastructure-as-Code (IaC) project for building a Kubernetes home lab cluster on Mac Mini M4 computers. The stack consists of:
- **K3s** - Lightweight Kubernetes distribution
- **Lima** - Linux VMs on macOS using Apple's virtualization framework
- **Ansible** - Infrastructure automation and orchestration
- **socket_vmnet** - Bridged networking for VMs
- **Thunderbolt bridge** - High-speed point-to-point connection between Mac Minis

## Commands

### Running Ansible Playbooks

All playbooks are executed from the project root using the inventory file:

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/<playbook>.yml
```

Key playbooks in execution order:
1. `01-install-lima.yml` - Install Lima VM manager
2. `02-install-docker.yml` - Install Docker Desktop via Homebrew
3. `03-install-socket-vmnet.yml` - Install socket_vmnet for bridged networking
4. `04-setup-lima-networking.yml` - Configure sudoers and Lima networking
5. `05-setup-launchd-service.yml` - Register socket_vmnet as launchd service
6. `06-setup-nat-forwarding.yml` - Configure pf NAT rules for VM-to-Thunderbolt and internet routing (requires `-K` flag)
7. `07-copy-k3s-configs.yml` - Distribute K3s Lima configurations to nodes
8. `08-install-k3s-master.yml` - Install K3s control plane on master VM (removes NoSchedule taint)
9. `09-join-k3s-worker.yml` - Join worker VM to the K3s cluster

For playbooks requiring sudo on remote hosts, add the `-K` flag to prompt for the password:
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/06-setup-nat-forwarding.yml -K
```

### Lima VM Operations

```bash
# Start VMs (on each Mac Mini)
limactl start --name=k3s-master ~/k3s-master.yaml
limactl start --name=k3s-worker ~/k3s-worker.yaml

# Shell into a VM
limactl shell k3s-master
limactl shell k3s-worker

# List VMs
limactl list

# Stop/delete VMs
limactl stop k3s-master
limactl delete k3s-master
```

### K3s Cluster Operations

From macmini-01 host:
```bash
# Check cluster status
limactl shell k3s-master -- sudo k3s kubectl get nodes

# Run kubectl commands
limactl shell k3s-master -- sudo k3s kubectl get pods -A

# Get node token (for manual worker joins)
limactl shell k3s-master -- sudo cat /var/lib/rancher/k3s/server/node-token
```

Note: The master node has the NoSchedule taint removed, allowing workloads to run on both master and worker.

## Architecture

### Network Topology

| Component | IP Address | Subnet |
|-----------|-----------|--------|
| macmini-01 (Thunderbolt) | 192.168.20.118 | 192.168.20.0/24 |
| macmini-02 (Thunderbolt) | 192.168.20.128 | 192.168.20.0/24 |
| VM networks | 192.168.64.x | 192.168.64.0/24 (vzNAT) |
| Ansible management | 192.168.1.x | 192.168.1.0/24 |

VMs run in isolated vzNAT networks (192.168.64.0/24). For VMs to communicate across the Thunderbolt bridge:
- IP forwarding must be enabled on each Mac host
- pf NAT rules translate VM traffic to the host's Thunderbolt IP
- NAT anchor (`/etc/pf.anchors/lima.nat`) must be referenced in `/etc/pf.conf`
- Traffic flow: VM → Mac host (NAT) → Thunderbolt bridge → Remote Mac

### Directory Structure

```
HomeLab/
├── ansible/
│   ├── inventory/hosts.ini      # Host definitions
│   ├── group_vars/mac_minis.yml # Shared variables
│   ├── playbooks/               # Numbered playbooks (01-09)
│   │   └── utilities/           # Helper playbooks
│   └── files/
│       ├── launchd/             # macOS service plists
│       └── scripts/             # Shell scripts
├── lima/                        # Lima VM configurations
├── kubernetes/manifests/        # K8s deployment manifests
├── scripts/                     # Utility scripts
└── docs/                        # Documentation
```

### Ansible Configuration

- **Inventory**: `ansible/inventory/hosts.ini`
- **Group variables**: `ansible/group_vars/mac_minis.yml`
  - `limactl`: Full path to limactl binary
  - `inet_interface`: Primary network interface (en1)
  - `thunderbolt_ip`: Per-host Thunderbolt bridge IP

Note: Playbooks using `limactl` require the full path `/opt/homebrew/bin/limactl` for non-interactive SSH sessions (defined in group_vars).
