# Configure Thunderbolt Bridge

This guide explains how to set up a Thunderbolt bridge between two Mac Minis to create a high-speed network connection for the Kubernetes cluster.

## 1. Physical Connection

Connect the two Mac Minis with a Thunderbolt cable.

## 2. Network Configuration

On each Mac, you will need to manually configure the Thunderbolt Bridge network interface. It is recommended to use a separate subnet for this connection to avoid conflicts with your existing network. We will use the `192.168.20.0/24` subnet.

### On `macmini_01`:

1.  Go to **System Settings > Network**.
2.  Select **Thunderbolt Bridge** from the list of network interfaces.
3.  Click on **Details...**
4.  Select **IPv4** from the sidebar.
5.  Set "Configure IPv4" to **Manually**.
6.  Enter the following:
    *   **IP Address:** `192.168.20.118`
    *   **Subnet Mask:** `255.255.255.0`
7.  Click **OK**.

### On `macmini_02`:

1.  Go to **System Settings > Network**.
2.  Select **Thunderbolt Bridge** from the list of network interfaces.
3.  Click on **Details...**
4.  Select **IPv4** from the sidebar.
5.  Set "Configure IPv4" to **Manually**.
6.  Enter the following:
    *   **IP Address:** `192.168.20.128`
    *   **Subnet Mask:** `255.255.255.0`
7.  Click **OK**.

## 3. Verification

To verify the connection, you can ping one Mac from the other using the newly configured IP addresses.

### From `macmini_01`:

Open the Terminal and run:

```bash
ping 192.168.20.128
```

### From `macmini_02`:

Open the Terminal and run:

```bash
ping 192.168.20.118
```

If the pings are successful, the Thunderbolt bridge is configured correctly. You can now proceed with the cluster setup, ensuring that any communication between the nodes (e.g., K3s configuration) uses these new IP addresses.
