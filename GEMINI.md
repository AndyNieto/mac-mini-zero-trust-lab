# Gemini Project Overview: Home Lab Setup

This directory contains Infrastructure-as-Code (IaC) for building a Kubernetes home lab cluster on Mac Mini M4 computers. The stack consists of:
- **K3s** - Lightweight Kubernetes distribution
- **Lima** - Linux VMs on macOS using Apple's virtualization framework
- **Ansible** - Infrastructure automation and orchestration
- **socket_vmnet** - Bridged networking for VMs (used for host-VM communication)
- **Thunderbolt bridge** - High-speed point-to-point connection between Mac Minis

## Architecture

### Network Topology

| Component | IP Address | Subnet |
|-----------|-----------|--------|
| macmini-01 (Thunderbolt) | 192.168.20.118 | 192.168.20.0/24 |
| macmini-02 (Thunderbolt) | 192.168.20.128 | 192.168.20.0/24 |
| macmini-01 (Management) | 192.168.1.118 | 192.168.1.0/24 |
| macmini-02 (Management) | 192.168.1.128 | 192.168.1.0/24 |
| VM networks | 192.168.64.x | 192.168.64.0/24 (vzNAT) |

### NAT and Routing

VMs run in isolated vzNAT networks (192.168.64.0/24). Two NAT rules are required on each Mac host:

1. **Thunderbolt NAT**: Routes VM traffic to the other Mac via Thunderbolt bridge
   ```
   nat on bridge0 from 192.168.64.0/24 to 192.168.20.0/24 -> <thunderbolt_ip>
   ```

2. **Internet NAT**: Routes VM traffic to the internet via the Mac's primary interface
   ```
   nat on en1 from 192.168.64.0/24 to any -> (en1)
   ```

These rules are stored in `/etc/pf.anchors/lima.nat` and loaded via the `lima.nat` pf anchor.

**Critical**: The anchor reference must be added to `/etc/pf.conf` in the correct position (after `nat-anchor "com.apple/*"` but before any filtering rules).

Traffic flow: VM → Mac host (NAT) → Thunderbolt bridge → Remote Mac → Remote VM

---

### Ansible Configuration

- **Inventory**: `ansible/inventory/hosts.ini`
  - Defines host groups and variables, including `thunderbolt_ip` for each host.
- **Group variables**: `ansible/group_vars/mac_minis.yml`
  - Contains shared variables like the full path to the `limactl` binary (`/opt/homebrew/bin/limactl`), primary network interface (`inet_interface`), and `thunderbolt_ip`.
  - Playbooks using `limactl` require the full path (`/opt/homebrew/bin/limactl`) for non-interactive SSH sessions. If `limactl` is not found, verify its path in `ansible/group_vars/mac_minis.yml`.

---

## Directory Structure

```
HomeLab/
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini                # Host definitions
│   ├── group_vars/
│   │   └── mac_minis.yml            # Shared variables (limactl path, network config)
│   ├── playbooks/
│   │   ├── 01-install-lima.yml
│   │   ├── 02-install-docker.yml
│   │   ├── 03-install-socket-vmnet.yml
│   │   ├── 04-setup-lima-networking.yml
│   │   ├── 05-setup-launchd-service.yml
│   │   ├── 06-setup-nat-forwarding.yml
│   │   ├── 07-copy-k3s-configs.yml
│   │   ├── 08-install-k3s-master.yml
│   │   ├── 09-join-k3s-worker.yml
│   │   └── utilities/               # Helper playbooks
│   └── files/
│       ├── launchd/                 # macOS launchd plist files
│       └── scripts/                 # Shell scripts for services
├── lima/
│   ├── k3s-master.yaml              # Master node VM config
│   ├── k3s-worker.yaml              # Worker node VM config
│   └── k3s-node.yaml                # Base/template config
├── kubernetes/
│   └── manifests/                   # K8s deployment manifests
├── scripts/                         # Utility scripts
├── docs/                            # Documentation
├── CLAUDE.md                        # AI assistant guidance
└── GEMINI.md                        # This file
```

---

## Complete Setup Sequence

### Phase 1: Physical Setup (Manual)

1. Connect two Mac Minis via Thunderbolt cable
2. On each Mac, go to **System Settings → Network → Thunderbolt Bridge**
3. Configure static IPs:
   - macmini-01: 192.168.20.118/24
   - macmini-02: 192.168.20.128/24
4. Verify connectivity: `ping 192.168.20.128` from macmini-01

### Phase 2: Prerequisites (Manual on Control Machine)

1. Install Ansible on your control machine (e.g., MacBook):
   ```bash
   brew install ansible
   ```

2. Set up SSH key authentication to both Mac Minis:
   ```bash
   ssh-copy-id homelab@192.168.1.118
   ssh-copy-id homelab@192.168.1.128
   ```

3. Verify Ansible connectivity:
   ```bash
   ansible -i ansible/inventory/hosts.ini mac_minis -m ping
   ```

### Phase 3: Install Infrastructure (Ansible)

Run these playbooks in order from the project root:

```bash
# 1. Install Lima VM manager
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/01-install-lima.yml

# 2. Install Docker Desktop
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/02-install-docker.yml

# 3. Install socket_vmnet for bridged networking
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/03-install-socket-vmnet.yml

# 4. Configure Lima networking and sudoers
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/04-setup-lima-networking.yml

# 5. Register socket_vmnet as launchd service
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/05-setup-launchd-service.yml

# 6. Configure NAT forwarding (requires sudo password)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/06-setup-nat-forwarding.yml -K

# 7. Copy K3s Lima configs to nodes
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/07-copy-k3s-configs.yml
```

### Phase 4: Start Lima VMs (On Each Mac Mini)

SSH to each Mac Mini and start the VMs:

**On macmini-01:**
```bash
limactl start --name=k3s-master ~/k3s-master.yaml
```

**On macmini-02:**
```bash
limactl start --name=k3s-worker ~/k3s-worker.yaml
```

### Phase 5: Verify NAT Configuration

Before installing K3s, verify VMs have network connectivity:

**Test internet access (from macmini-01):**
```bash
limactl shell k3s-master -- ping -c 2 8.8.8.8
```

**Test Thunderbolt connectivity (from macmini-01's VM to macmini-02):**
```bash
limactl shell k3s-master -- ping -c 2 192.168.20.128
```

If either fails, see Troubleshooting section below.

### Phase 6: Deploy K3s Cluster (Ansible)

```bash
# Install K3s master (on macmini-01's VM)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/08-install-k3s-master.yml

# Join worker to cluster (on macmini-02's VM)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/09-join-k3s-worker.yml
```

### Phase 7: Verify Cluster

```bash
limactl shell k3s-master -- sudo k3s kubectl get nodes
```

Expected output:
```
NAME              STATUS   ROLES           AGE   VERSION
lima-k3s-master   Ready    control-plane   Xm    v1.34.x+k3s1
lima-k3s-worker   Ready    <none>          Xm    v1.34.x+k3s1
```

---

## Troubleshooting

### VM Cannot Reach Internet

**Symptom:** `ping 8.8.8.8` fails from inside the VM

**Cause:** Missing internet NAT rule

**Fix (on Mac host):**
```bash
# Add internet NAT rule
echo 'nat on en1 from 192.168.64.0/24 to any -> (en1)' | sudo tee -a /etc/pf.anchors/lima.nat

# Reload NAT anchor
sudo pfctl -a lima.nat -f /etc/pf.anchors/lima.nat

# Verify
sudo pfctl -a lima.nat -s nat
```

### VM Cannot Reach Other Mac via Thunderbolt

**Symptom:** VM can ping local bridge0 (192.168.20.118) but not remote (192.168.20.128)

**Cause:** NAT anchor not referenced in pf.conf, or in wrong position

**Diagnosis:**
```bash
# Check if anchor is referenced
sudo pfctl -s nat | grep lima.nat

# Check rules inside anchor
sudo pfctl -a lima.nat -s nat
```

**Fix:**
```bash
# Check current pf.conf
cat /etc/pf.conf

# The lima.nat anchor must appear AFTER nat-anchor "com.apple/*"
# If missing or in wrong place, edit /etc/pf.conf:
sudo vi /etc/pf.conf

# Add this line after 'nat-anchor "com.apple/*"':
nat-anchor "lima.nat"

# Reload pf configuration
sudo pfctl -f /etc/pf.conf
```

### K3s Install Script Fails with Shell Errors

**Cause:** Piped commands don't work well through `limactl shell`

**Fix:** Download script first, then execute:
```bash
limactl shell k3s-master -- curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
limactl shell k3s-master -- sudo sh /tmp/k3s-install.sh
```

### IP Forwarding Not Enabled

**Check:**
```bash
sysctl net.inet.ip.forwarding
```

**Fix:**
```bash
sudo sysctl -w net.inet.ip.forwarding=1
echo "net.inet.ip.forwarding=1" | sudo tee -a /etc/sysctl.conf
```

---

## Lima VM Operations

```bash
# Start VMs
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

## K3s Cluster Operations

From the `macmini-01` host:

```bash
# Check cluster status
limactl shell k3s-master -- sudo k3s kubectl get nodes

# Run kubectl commands
limactl shell k3s-master -- sudo k3s kubectl get pods -A

# Get node token (for manual worker joins)
limactl shell k3s-master -- sudo cat /var/lib/rancher/k3s/server/node-token
```

**Note:** The master node has the NoSchedule taint removed, allowing workloads to run on both master and worker nodes.

---

## Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/06-setup-nat-forwarding.yml` | Configures pf NAT rules for VM routing |
| `ansible/playbooks/08-install-k3s-master.yml` | Installs K3s control plane |
| `ansible/playbooks/09-join-k3s-worker.yml` | Joins worker to cluster |
| `/etc/pf.anchors/lima.nat` | NAT rules for VM traffic (on each Mac) |
| `/etc/pf.conf` | Must reference lima.nat anchor (on each Mac) |
| `lima/k3s-master.yaml` | Lima VM config for master node |
| `lima/k3s-worker.yaml` | Lima VM config for worker node |
