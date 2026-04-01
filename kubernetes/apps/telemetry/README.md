# Phase 2: Telemetry & Logging

Log aggregation and distributed tracing infrastructure.

## Components

| Component | Purpose | Status |
|-----------|---------|--------|
| Grafana Loki | Log aggregation (like Prometheus for logs) | Deployed |
| Promtail | Log shipping agent (DaemonSet) | Deployed |
| OpenTelemetry Collector | Telemetry pipeline (traces, metrics, logs) | Deployed |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      K3s Cluster                            │
│                                                             │
│  ┌─────────────┐     ┌─────────────┐     ┌──────────────┐  │
│  │   Promtail  │────▶│    Loki     │◀────│   Grafana    │  │
│  │  (DaemonSet)│     │  (storage)  │     │  (query UI)  │  │
│  └─────────────┘     └─────────────┘     └──────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            OpenTelemetry Collector                   │   │
│  │  Receivers ──▶ Processors ──▶ Exporters             │   │
│  │  (OTLP)       (batch)        (Prometheus, Loki)     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Deployment

```bash
# Deploy the stack
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/telemetry/deploy.yml

# Check status
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/telemetry/status.yml
```

## Accessing Logs in Grafana

1. Open Grafana: http://localhost:3000 (via SSH tunnel)
2. Click **Explore** (compass icon in sidebar)
3. Select **Loki** from the datasource dropdown
4. Try these queries:

```logql
# All logs from monitoring namespace
{namespace="monitoring"}

# Logs from a specific pod
{pod="prometheus-grafana-xxxxx"}

# Filter by content
{namespace="kube-system"} |= "error"

# Count errors per app
count_over_time({namespace="monitoring"} |= "error" [5m])
```

## LogQL Basics

LogQL is Loki's query language (similar to PromQL):

| Query | Description |
|-------|-------------|
| `{label="value"}` | Select by label |
| `|= "text"` | Line contains text |
| `!= "text"` | Line doesn't contain text |
| `|~ "regex"` | Line matches regex |
| `| json` | Parse JSON logs |
| `| logfmt` | Parse logfmt logs |

## OpenTelemetry Endpoints

Applications can send telemetry to:

| Protocol | Endpoint | Port |
|----------|----------|------|
| OTLP gRPC | `otel-collector.telemetry:4317` | 4317 |
| OTLP HTTP | `otel-collector.telemetry:4318` | 4318 |

## Prerequisites

- Phase 1 (Monitoring) must be deployed first
- Grafana from Phase 1 is reused for visualization

## Resources

- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/logql/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
