#!/bin/bash
LIMA_DIR="/var/run/lima"
PID_FILE="$LIMA_DIR/bridged_socket_vmnet_bridge0.pid"

mkdir -p "$LIMA_DIR"
chown root:daemon "$LIMA_DIR"
chmod 775 "$LIMA_DIR"

rm -f "$PID_FILE"

/opt/homebrew/opt/socket_vmnet/bin/socket_vmnet \
  --pidfile="$PID_FILE" \
  --socket-group=everyone \
  --vmnet-mode=bridged \
  --vmnet-interface=bridge0 \
  "$LIMA_DIR/socket_vmnet.bridge0"
