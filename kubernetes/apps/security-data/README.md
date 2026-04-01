# Phase 3: Security Data Normalization

Security log enrichment and OCSF transformation using Tenzir.

## Components

| Component | Purpose | Status |
|-----------|---------|--------|
| Tenzir | Security data pipeline engine | Deployed |
| OCSF Pipelines | Transform logs to OCSF schema | Configured |

## What is OCSF?

**Open Cybersecurity Schema Framework** — a vendor-neutral standard for security events.

### The Problem (Before OCSF)

Every security tool uses different field names:

```json
// Firewall A
{"src": "10.0.0.1", "dst": "8.8.8.8", "action": "DENY"}

// Firewall B
{"source_ip": "10.0.0.1", "destination_ip": "8.8.8.8", "decision": "blocked"}

// IDS
{"attacker": "10.0.0.1", "target": "8.8.8.8", "result": "dropped"}
```

### The Solution (After OCSF)

All events follow the same structure:

```json
{
  "class_uid": 4001,
  "class_name": "Network Activity",
  "category_uid": 4,
  "src_endpoint": {"ip": "10.0.0.1"},
  "dst_endpoint": {"ip": "8.8.8.8"},
  "action_id": 2,
  "action": "Blocked"
}
```

## What is Tenzir?

Tenzir is a **security data pipeline engine** designed for:
- Ingesting logs from various sources
- Parsing and enriching security events
- Transforming data to OCSF schema
- Routing to destinations (Loki, Elasticsearch, S3, etc.)

### Why Tenzir?

| Feature | Tenzir | Vector | Fluent Bit |
|---------|--------|--------|------------|
| Security focus | ✅ Native | ❌ General | ❌ General |
| OCSF support | ✅ Built-in | ❌ Manual | ❌ Manual |
| Query language | ✅ TQL | VRL | Limited |
| GUI | ✅ Web UI | ❌ None | ❌ None |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   ┌──────────┐     ┌─────────────────────┐     ┌──────────┐    │
│   │ Promtail │────▶│       Tenzir        │────▶│   Loki   │    │
│   │ (raw)    │     │                     │     │ (OCSF)   │    │
│   └──────────┘     │  1. Parse logs      │     └──────────┘    │
│                    │  2. Enrich data     │                      │
│   ┌──────────┐     │  3. Map to OCSF     │     ┌──────────┐    │
│   │ OTel     │────▶│  4. Route output    │────▶│Prometheus│    │
│   │ Collector│     │                     │     │(metrics) │    │
│   └──────────┘     └─────────────────────┘     └──────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment

```bash
# Deploy the stack
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/security-data/deploy.yml

# Check status
kubectl get pods -n security-data
```

## Accessing Tenzir

Add to your SSH tunnel:

```bash
ssh -L 5160:192.168.64.2:30160 -L 5158:192.168.64.2:30158 homelab@192.168.1.118
```

Then open: http://localhost:5160

## OCSF Event Classes

| Class UID | Class Name | Description |
|-----------|------------|-------------|
| 1001 | File Activity | File create, modify, delete |
| 2001 | Device Config State | Device configuration changes |
| 3001 | Authentication | Login, logout, auth failures |
| 4001 | Network Activity | Network connections, traffic |
| 5001 | Inventory Info | Asset discovery |
| 6001 | Web Resources | HTTP requests, web activity |

## Example TQL Pipelines

### Parse Syslog and Map to OCSF

```tql
// Ingest from syslog
from syslog
| parse syslog
| ocsf.map --category="System Activity"
| to loki
```

### Filter Authentication Events

```tql
from loki --query='{namespace="monitoring"}'
| where message contains "authentication"
| ocsf.map --class=3001
| to stdout
```

## Resources

- [OCSF Schema](https://schema.ocsf.io/)
- [Tenzir Documentation](https://docs.tenzir.com/)
- [TQL Reference](https://docs.tenzir.com/tql2/operators)
