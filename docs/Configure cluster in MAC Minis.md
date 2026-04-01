# Configure cluster in MAC Minis

This document outlines the steps to configure the Mac Mini cluster. The steps in this guide should be followed for each Mac Mini to ensure a consistent configuration.

# Prerequisites

## Configure Thunderbolt Bridge

Before proceeding with the cluster setup, it is recommended to configure a Thunderbolt bridge between the two Mac Minis for a high-speed network connection.

Follow the instructions in the [Thunderbolt Bridge.md](./Thunderbolt%20Bridge.md) guide to set up the connection.

# Installing Docker on the Host (Mac Minis)

This section details the steps required to install Docker on the `macmini-01` and macmini-02 hosts.

## 1. Manual Configurations/Installation

### 1.1 General Settings ###
Login to the local macMini, and enable the following settings to allow  the following setting
* Remote Management:
	* Only these users : homelab
		* Allow Observer and Control
* Remote Login:
	* Only these users: Administratros, homelab
* Remote Application Scripting:
	* Only these users: Administrators, homelab

### 1.2 Update Hostname ###
From the terminal run the following command, then reboot the machine

`sudo scutil --set HostName macmini_02`
`sudo reboot`

### 1.2 Homebrew Installation ###

The Ansible playbook for installing Homebrew failed due to issues with remote execution and `sudo` permissions. Therefore, Homebrew needs to be installed manually on each Mac Mini.

Log in to the Mac Mini and run the following command in the terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 2. Ansible Playbook for Docker

Once Homebrew is installed, you can use the `install_docker.yml` Ansible playbook to install Docker. This playbook is configured to use Homebrew for the installation.

Before running the playbook, make sure the `ansible/inventory.ini` file has the correct IP address for the Mac Mini.

Then, run the playbook with the following command:

```bash
ansible-playbook -i ansible/inventory.ini ansible/install_docker.yml
```

**Important Notes:**
*   The `install_docker.yml` playbook has been modified to handle the fact that `homebrew/cask` tapping is no longer necessary.
*   The playbook also sets the `PATH` environment variable to ensure the `brew` executable is found at `/opt/homebrew/bin`.

## 3. Verification

After the playbook has finished, you can verify the Docker installation by running the `verify_docker.yml` playbook:

```bash
ansible-playbook -i ansible/inventory.ini ansible/verify_docker.yml
```

This playbook will check for the Docker executable at `/usr/local/bin/docker` and print the version if it's found.

### Fixing issues installing Lima VM
```
# Remove the incorrect symbolic link
sudo rm /opt/socket_vmnet/bin/socket_vmnet

# Re-create the directory to be safe
sudo mkdir -p /opt/socket_vmnet/bin

# Delete any failed Lima instance
limactl delete swarm-node

#Create the hardcopy of socket_vmnet
# 1. Copy the file
sudo cp /opt/homebrew/opt/socket_vmnet/bin/socket_vmnet /opt/socket_vmnet/bin/

# 2. Make it executable
sudo chmod +x /opt/socket_vmnet/bin/socket_vmnet

#Setup Sudoer Permissions
limactl sudoers >etc_sudoers.d_lima && sudo install -o root etc_sudoers.d_lima "/private/etc/sudoers.d/lima"

#Launch the VM
limactl start --name=swarm-node ./Desktop/swarm-node.yaml
```

 1. Connecting To Lima VM
Run the following command to get into the command line of the VM
```
limactl shell swarm-node
```

2. Run the Docker Install Script (inside the VM shell):
```
# Run this on both VMs
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER
# Exit and re-enter the shell to apply group changes
exit
lima shell swarm-node
```

3. Install K3s on the Control-Plane Node (Mac-mini-1)
In the terminal window for **Mac-mini-1's VM**, run the official K3s installation script. This single command installs all the necessary control-plane components and the `kubectl` command-line tool for managing the cluster.
```
# Inside VM-1's shell
curl -sfL https://get.k3s.io | sh -
```

* Find the IP address of the control plane
```ip a | grep 'inet ' ```
	
* Get the Cluster's Join Token:** This is like a secret password that allows other nodes to join.
	```# Inside VM-1's shell
	sudo cat /var/lib/rancher/k3s/server/node-token
	```

This will print a long string of characters (e.g., `K10...::server:abc...`). **Copy this entire token string exactly.**

4. Join the worker node to the cluster
```
# Inside VM-2's shell
curl -sfL https://get.k3s.io | K3S_URL='https://<IP_OF_SERVER_NODE>:6443' K3S_TOKEN='<COPIED_TOKEN_HERE>' sh -
```