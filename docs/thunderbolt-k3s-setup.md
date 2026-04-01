# Thunderbolt Bridge Setup for K3s Cluster with Lima VMs

## Overview
This guide configures two Mac Mini M4s connected via Thunderbolt bridge to run a K3s cluster using Lima VMs, with traffic flowing through the high-speed Thunderbolt connection.

**Network Topology:**
```
macmini-01 (Master):
  - Mac host: 192.168.20.118 (bridge0 - Thunderbolt)
  - VM: 192.168.64.2 (lima0 - vzNAT)

macmini-02 (Worker):
  - Mac host: 192.168.20.128 (bridge0 - Thunderbolt)
  - VM: 192.168.64.2 (lima0 - vzNAT)

Traffic flow: VM → Mac host → Thunderbolt bridge → Remote Mac host → Remote VM
```

## Prerequisites
- Two Mac Mini M4s connected via Thunderbolt cable
- Thunderbolt bridge configured on both Macs
- Lima installed: `brew install lima`
- socket_vmnet installed: `brew install socket_vmnet`

---

## Configuration: macmini-01 (Master Node)

### 1. Install socket_vmnet
```bash
brew install socket_vmnet
sudo brew services start socket_vmnet
```

### 2. Verify Thunderbolt Bridge
```bash
ifconfig bridge0
# Should show: inet 192.168.20.118
```

### 3. Enable IP Forwarding
```bash
# Enable IP forwarding
sudo sysctl -w net.inet.ip.forwarding=1

# Make it permanent
echo "net.inet.ip.forwarding=1" | sudo tee -a /etc/sysctl.conf
```

### 4. Configure NAT for VM Traffic
```bash
# Create NAT rules directory and file
sudo mkdir -p /etc/pf.anchors

cat <<EOF | sudo tee /etc/pf.anchors/lima.nat
# NAT rule for Lima VMs to reach Thunderbolt network
nat on bridge0 from 192.168.64.0/24 to 192.168.20.0/24 -> 192.168.20.118
EOF

# Load the NAT rule
echo "nat-anchor \"lima.nat\"" | sudo pfctl -f -
sudo pfctl -a lima.nat -f /etc/pf.anchors/lima.nat
sudo pfctl -e
```

### 5. Create Lima Configuration
Create `~/k3s-master.yaml`:

```yaml
images:
- location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
  arch: "aarch64"

cpus: 2
memory: "4GiB"
disk: "30GiB"

vmType: "vz"

networks:
- vzNAT: true

portForwards:
- guestPort: 6443
  hostPort: 6443
  hostIP: "192.168.20.118"

mounts:
- location: "~"
  writable: false
- location: "/tmp/lima"
  writable: true

containerd:
  system: true
  user: false
```

### 6. Create and Start the VM
```bash
# If VM already exists, delete it
limactl delete k3s-master

# Start the VM
limactl start --name=k3s-master ~/k3s-master.yaml
```

### 7. Verify Connectivity
```bash
# Enter the VM
limactl shell k3s-master

# Check network configuration
ip addr show
# Should show lima0 with 192.168.64.2

# Test connectivity to macmini-02
ping 192.168.20.128
```

---

## Configuration: macmini-02 (Worker Node)

### 1. Install socket_vmnet
```bash
brew install socket_vmnet
sudo brew services start socket_vmnet
```

### 2. Verify Thunderbolt Bridge
```bash
ifconfig bridge0
# Should show: inet 192.168.20.128
```

### 3. Enable IP Forwarding
```bash
# Enable IP forwarding
sudo sysctl -w net.inet.ip.forwarding=1

# Make it permanent
echo "net.inet.ip.forwarding=1" | sudo tee -a /etc/sysctl.conf
```

### 4. Configure NAT for VM Traffic
```bash
# Create NAT rules directory and file
sudo mkdir -p /etc/pf.anchors

cat <<EOF | sudo tee /etc/pf.anchors/lima.nat
# NAT rule for Lima VMs to reach Thunderbolt network
nat on bridge0 from 192.168.64.0/24 to 192.168.20.0/24 -> 192.168.20.128
EOF

# Load the NAT rule
echo "nat-anchor \"lima.nat\"" | sudo pfctl -f -
sudo pfctl -a lima.nat -f /etc/pf.anchors/lima.nat
sudo pfctl -e
```

### 5. Create Lima Configuration
Create `~/k3s-worker.yaml`:

```yaml
images:
- location: "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-arm64.img"
  arch: "aarch64"

cpus: 2
memory: "4GiB"
disk: "30GiB"

vmType: "vz"

networks:
- vzNAT: true

mounts:
- location: "~"
  writable: false
- location: "/tmp/lima"
  writable: true

containerd:
  system: true
  user: false
```

### 6. Create and Start the VM
```bash
# If VM already exists, delete it
limactl delete k3s-worker

# Start the VM
limactl start --name=k3s-worker ~/k3s-worker.yaml
```

### 7. Verify Connectivity
```bash
# Enter the VM
limactl shell k3s-worker

# Check network configuration
ip addr show
# Should show lima0 with 192.168.64.2

# Test connectivity to macmini-01
ping 192.168.20.118
```

---

## Verify Thunderbolt Traffic

### Test 1: Monitor Traffic on Thunderbolt Bridge
```bash
# On macmini-01, run tcpdump
sudo tcpdump -i bridge0 -n icmp

# On macmini-02, from within the VM
limactl shell k3s-worker
ping 192.168.20.118
```

You should see ICMP packets with NAT translation:
```
IP 192.168.20.128 > 192.168.20.118: ICMP echo request
IP 192.168.20.118 > 192.168.20.128: ICMP echo reply
```

### Test 2: Bandwidth Test (Confirms Thunderbolt Speed)
```bash
# On macmini-01 VM (master)
limactl shell k3s-master
sudo apt update && sudo apt install -y iperf3
iperf3 -s

# On macmini-02 VM (worker)
limactl shell k3s-worker
sudo apt update && sudo apt install -y iperf3
iperf3 -c 192.168.20.118
```

Expected result: **10+ Gbps** (Thunderbolt speeds)

---

## Deploy K3s Cluster

### On macmini-01 (Master)
```bash
limactl shell k3s-master

# Install K3s master
curl -sfL https://get.k3s.io | sh -

# Get the node token
sudo cat /var/lib/rancher/k3s/server/node-token
# Copy this token for the worker
```

### On macmini-02 (Worker)
```bash
limactl shell k3s-worker

# Join the cluster (replace <TOKEN> with actual token)
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.20.118:6443 K3S_TOKEN=<TOKEN> sh -
```

### Verify Cluster
```bash
# On master VM
limactl shell k3s-master
sudo k3s kubectl get nodes
```

You should see both master and worker nodes in Ready state.

---

## Troubleshooting

### "Unknown state" on Thunderbolt Bridge
This is **normal** for a point-to-point network without internet access. It doesn't affect functionality.

### VMs can't reach each other
1. Verify IP forwarding: `sysctl net.inet.ip.forwarding` (should be 1)
2. Check NAT rules are loaded: `sudo pfctl -s nat`
3. Verify routing: `netstat -rn | grep 192.168.20`

### NAT rules don't persist after reboot
Add to both Mac hosts:
```bash
# Create a launchd plist to load NAT rules on boot
cat <<EOF | sudo tee /Library/LaunchDaemons/com.lima.nat.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lima.nat</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>pfctl -a lima.nat -f /etc/pf.anchors/lima.nat; pfctl -e</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

sudo launchctl load /Library/LaunchDaemons/com.lima.nat.plist
```

### Verify Traffic is Using Thunderbolt
```bash
# On either Mac host
sudo tcpdump -i bridge0 -n
# You should see traffic flowing
```

---

## Key Insights

1. **Lima VMs can't directly bridge to Mac network interfaces** - they use isolated networks
2. **vzNAT + NAT forwarding** is the solution for VM-to-VM communication via Thunderbolt
3. **Port forwarding** allows K3s worker to reach master's API server through Mac hosts
4. **Both VMs can have the same IP** because they're on separate physical hosts
5. **Traffic flows through Mac hosts** using NAT translation on the Thunderbolt bridge

## Summary

This setup provides:
- ✅ High-speed Thunderbolt connectivity between cluster nodes
- ✅ Isolated VM networks with secure NAT
- ✅ Proper K3s cluster communication
- ✅ Easy to verify and troubleshoot

The "Unknown state" on the Thunderbolt bridge is cosmetic and doesn't affect performance.