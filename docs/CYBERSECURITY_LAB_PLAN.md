# Cybersecurity Lab Learning Plan

A 6-month structured plan to build a comprehensive cybersecurity lab on the K3s home cluster, progressing from observability fundamentals to AI-powered security analytics.

## Goals

- Build hands-on penetration testing skills in an isolated lab environment
- Implement production-grade observability (Prometheus, Grafana, OpenTelemetry)
- Master security data normalization using OCSF schema
- Deploy Zero Trust architecture patterns
- Prepare for NVIDIA Morpheus experimentation (future - requires GPU hardware)

---

## Current Progress Summary

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Observability | ✅ Complete | Prometheus, Grafana, Alertmanager deployed |
| Phase 2: Telemetry | ✅ Complete | Loki, Promtail, OTel Collector, Jaeger all running |
| Phase 3: Security Data | 🔄 In Progress | Tenzir + Fluent Bit pipeline verified; OCSF pipelines pending |
| Phase 4: Penetration Testing | 🔄 In Progress | Manifests + deploy.yml created; ready to deploy |
| Phase 5: Zero Trust | ❌ Not Started | Service mesh, mTLS pending |
| Phase 6: AI Security | ⏳ Future | Requires GPU hardware |

**Last Updated:** 2026-02-26

---

## Architecture Diagrams

### End-State Infrastructure

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              HARDWARE LAYER                                      │
│  ┌─────────────────────────┐      Thunderbolt      ┌─────────────────────────┐  │
│  │      macmini-01         │◄────────────────────►│      macmini-02         │  │
│  │    192.168.20.118       │      Bridge           │    192.168.20.128       │  │
│  └───────────┬─────────────┘                       └───────────┬─────────────┘  │
│              │ Lima                                             │ Lima           │
│  ┌───────────▼─────────────┐                       ┌───────────▼─────────────┐  │
│  │   k3s-master (VM)       │                       │   k3s-worker (VM)       │  │
│  │   Control Plane         │◄─────────────────────►│   Worker Node           │  │
│  └─────────────────────────┘      K3s Cluster      └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES NAMESPACES                                  │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │  MONITORING NAMESPACE                                                      │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                     │  │
│  │  │  Prometheus  │  │   Grafana    │  │ Alertmanager │                     │  │
│  │  │  (metrics)   │  │ (dashboards) │  │  (alerts)    │                     │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                     │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │  TELEMETRY NAMESPACE                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │   Promtail   │  │     Loki     │  │     OTel     │  │    Jaeger    │   │  │
│  │  │ (DaemonSet)  │─▶│   (logs)     │  │  Collector   │  │  (traces)    │   │  │
│  │  └──────────────┘  └──────────────┘  └──────┬───────┘  └──────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                │                                 │
│                              ┌─────────────────┴─────────────────┐              │
│                              │         LOG ROUTING               │              │
│                              │  Security logs    General logs    │              │
│                              └────────┬──────────────┬───────────┘              │
│                                       │              │                          │
│                                       ▼              ▼                          │
│  ┌────────────────────────────────────────┐  ┌──────────────┐                   │
│  │  SECURITY-DATA NAMESPACE               │  │    Loki      │                   │
│  │  ┌──────────────┐  ┌──────────────┐    │  │  (storage)   │                   │
│  │  │  Fluent Bit  │  │    Tenzir    │    │  └──────────────┘                   │
│  │  │  (forward)   │─▶│(OCSF transform)│   │                                    │
│  │  └──────────────┘  └──────┬───────┘    │                                     │
│  │                           │            │                                     │
│  │                           ▼            │                                     │
│  │                    ┌──────────────┐    │                                     │
│  │                    │     SIEM     │    │                                     │
│  │                    │ (lightweight)│    │                                     │
│  │                    └──────────────┘    │                                     │
│  └────────────────────────────────────────┘                                     │
│                                                                                  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │  VULN-LAB NAMESPACE (Penetration Testing Targets)                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │    DVWA      │  │  Juice Shop  │  │  WebGoat     │  │   Others     │   │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Observability & Security Data Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            DATA SOURCES (Pod Logs)                               │
│                                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │ vuln-lab    │  │ security-   │  │ kube-system │  │ monitoring  │            │
│  │ namespace   │  │ data ns     │  │ namespace   │  │ /telemetry  │            │
│  │             │  │             │  │             │  │ namespaces  │            │
│  │ • DVWA      │  │ • Tenzir    │  │ • CoreDNS   │  │ • Prometheus│            │
│  │ • JuiceShop │  │ • FluentBit │  │ • Flannel   │  │ • Grafana   │            │
│  │ • WebGoat   │  │             │  │ • Traefik   │  │ • Loki      │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         └─────────────────┴────────────────┴────────────────┘                   │
│                           All write to /var/log/pods/                            │
└───────────────────────────────────┬─────────────────────────────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
┌─────────────────────────┐ ┌─────────────┐ ┌─────────────────────────┐
│  PATH 1: OBSERVABILITY  │ │  PATH 2:    │ │  PATH 3: SECURITY DATA  │
│                         │ │  FUTURE     │ │                         │
│  Promtail (DaemonSet)   │ │  OTel       │ │  Fluent Bit (DaemonSet) │
│  Tails /var/log/pods/*  │ │  Collector  │ │  Tails /var/log/pods/*  │
│  Adds K8s labels        │ │             │ │  Excludes own logs      │
│         │               │ │  Receives   │ │         │               │
│         │ Loki Push     │ │  OTLP from  │ │         │ Forward       │
│         │ Protocol      │ │  instrumented│ │         │ Protocol      │
│         ▼               │ │  apps (push)│ │         ▼               │
│  ┌───────────────────┐  │ │             │ │  ┌───────────────────┐  │
│  │       Loki        │  │ │  :4317 gRPC │ │  │      Tenzir       │  │
│  │  • Label index    │  │ │  :4318 HTTP │ │  │  • :24224 receive │  │
│  │  • LogQL queries  │  │ │  :3500 Loki │ │  │  • OCSF transform │  │
│  │  • All namespaces │  │ │             │ │  │  • All namespaces │  │
│  └────────┬──────────┘  │ │  Namespace  │ │  └────────┬──────────┘  │
│           ▼              │ │  routing:   │ │           ▼              │
│  ┌───────────────────┐  │ │  security → │ │  ┌───────────────────┐  │
│  │     Grafana       │  │ │    debug*   │ │  │  Tenzir Cloud UI  │  │
│  │  • Explore logs   │  │ │  general →  │ │  │  app.tenzir.com   │  │
│  │  • Dashboards     │  │ │    loki     │ │  └────────┬──────────┘  │
│  └───────────────────┘  │ │             │ │           ▼              │
│                         │ │ *not yet    │ │  ┌───────────────────┐  │
│  ✅ ACTIVE              │ │  wired to   │ │  │    SIEM (future)  │  │
│                         │ │  Tenzir     │ │  │  • Correlation     │  │
└─────────────────────────┘ │             │ │  │  • Threat detect  │  │
                            │ ⏳ PARTIAL   │ │  └───────────────────┘  │
                            └─────────────┘ │                         │
                                            │  ✅ ACTIVE              │
                                            └─────────────────────────┘

STATUS:
  Path 1 (Promtail → Loki → Grafana):      ✅ Fully active
  Path 2 (OTel Collector):                  ⏳ Deployed, general→Loki active,
                                               security→Tenzir not yet wired
  Path 3 (Fluent Bit → Tenzir):             ✅ Verified 2026-02-10
```

### Metrics & Traces Pipeline

```
METRICS PIPELINE:

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Applications   │     │  Node Exporter  │     │ Kube-State-     │
│  /metrics       │     │  (DaemonSet)    │     │ Metrics         │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         └───────────────────────┼───────────────────────┘
                                 │ SCRAPE (pull)
                                 ▼
                    ┌────────────────────────┐
                    │      Prometheus        │
                    │  • Time-series DB      │
                    │  • PromQL queries      │
                    └───────────┬────────────┘
                   ┌────────────┴────────────┐
                   ▼                         ▼
        ┌─────────────────┐       ┌─────────────────┐
        │    Grafana      │       │  Alertmanager   │
        │  (dashboards)   │       │  (routing)      │
        └─────────────────┘       └─────────────────┘

TRACES PIPELINE (Active):

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  App Service A  │────▶│  App Service B  │────▶│  App Service C  │
│  (instrumented) │     │  (instrumented) │     │  (instrumented) │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         └───────────────────────┼───────────────────────┘
                                 │ OTLP (push spans)
                                 ▼
                    ┌────────────────────────┐
                    │    OTel Collector      │  ✅ Running
                    └───────────┬────────────┘
                                ▼
                    ┌────────────────────────┐
                    │        Jaeger          │  ✅ Running
                    │  • Trace visualization │
                    │  • Latency analysis    │
                    │  • UI: NodePort 30686  │
                    └────────────────────────┘

Note: Pipeline is plumbed and verified. No apps are instrumented yet —
Jaeger will show real data once security tools emit traces in Phase 3+.
```

---

## Deployment Checklist

Legend: ✅ Complete | 🔄 In Progress | ❌ Not Started | ⏳ Planned

### Infrastructure (Phase 0)

| Component | Status | Notes |
|-----------|--------|-------|
| macmini-01 (primary) | ✅ | 192.168.1.118 / 192.168.20.118 (TB) |
| macmini-02 (secondary) | ✅ | 192.168.1.128 / 192.168.20.128 (TB) |
| Thunderbolt bridge | ✅ | 192.168.20.0/24 |
| Lima VMs | ✅ | k3s-master, k3s-worker |
| K3s cluster | ✅ | Control plane + worker |
| kubectl/helm | ✅ | Configured |

**Known Limitations:**
- Both VMs have same IP (192.168.64.2) due to Lima vzNAT
- kubectl exec/logs may fail with 502 - use crictl as workaround
- Pods forced to master node via nodeSelector for reliability

---

## Phase 1: Observability Foundation ✅ COMPLETE

### Objectives
- Deploy Prometheus for metrics collection
- Set up Grafana for visualization
- Understand Kubernetes monitoring patterns

### Deployed Components

| Component | Namespace | Status | Access |
|-----------|-----------|--------|--------|
| Prometheus | monitoring | ✅ Running | localhost:9090 (via SSH tunnel) |
| Grafana | monitoring | ✅ Running | localhost:3000 (admin/homelab-admin) |
| Alertmanager | monitoring | ✅ Running | localhost:9093 (via SSH tunnel) |
| Node Exporter | monitoring | ✅ DaemonSet | Metrics on each node |
| Kube State Metrics | monitoring | ✅ Running | K8s object metrics |

### Tasks Completed

#### Week 1-2: Prometheus Stack
- [x] Install Prometheus Operator (kube-prometheus-stack Helm chart)
- [x] Configure ServiceMonitors for K3s components
- [x] Set up AlertManager with basic rules
- [x] Understand PromQL basics

#### Week 3-4: Grafana Dashboards
- [x] Access Grafana UI and explore built-in dashboards
- [x] Built-in Kubernetes dashboards available
- [x] Configure persistent storage for Grafana (PVC)

### Access Instructions
```bash
# SSH tunnel for Grafana
ssh -L 3000:192.168.64.2:30300 homelab@192.168.1.118

# Open in browser
open http://localhost:3000
# Credentials: admin / homelab-admin
```

### Resources
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Grafana Fundamentals](https://grafana.com/tutorials/grafana-fundamentals/)
- Book: "Prometheus: Up & Running" by Brian Brazil

---

## Phase 2: Telemetry & Logging ✅ COMPLETE

### Objectives
- Implement OpenTelemetry for distributed tracing
- Set up centralized logging with Loki
- Understand the three pillars: metrics, logs, traces

### Deployed Components

| Component | Namespace | Status | Notes |
|-----------|-----------|--------|-------|
| Loki | telemetry | ✅ Running | SingleBinary mode, filesystem storage, tsdb schema |
| Promtail | telemetry | ✅ DaemonSet | Shipping logs from both nodes to Loki |
| OTel Collector | telemetry | ✅ Running | OTLP receivers, namespace routing |
| Jaeger | telemetry | ✅ Running | All-in-one v2, OTLP on 4317/4318, UI on NodePort 30686 |

### Tasks

#### Week 5-6: OpenTelemetry
- [x] Deploy OpenTelemetry Collector in K3s
- [x] Configure OTLP receivers (gRPC:4317, HTTP:4318)
- [x] Configure Loki receiver (port 3500)
- [x] Set up namespace-based log routing (security vs general)
- [x] Deploy Jaeger for trace visualization
- [x] Configure OTel Collector trace exporter to Jaeger
- [x] Verify end-to-end trace pipeline (test span visible in Jaeger UI)
- [ ] Instrument a sample application with OTel SDK

#### Week 7-8: Loki for Logs
- [x] Deploy Grafana Loki (migrated from deprecated loki-stack to standalone grafana/loki)
- [x] Configure Promtail as log shipper (both master + worker nodes)
- [x] Configure Grafana datasource for Loki
- [x] Verify logs flowing in Grafana Explore
- [ ] Build unified dashboard (metrics + logs + traces)

### Resources
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)

---

## Phase 3: Security Data Normalization 🔄 IN PROGRESS

### Objectives
- Understand OCSF (Open Cybersecurity Schema Framework)
- Implement normalized security event logging
- Build data pipelines for security analytics

### Deployed Components

| Component | Namespace | Status | Notes |
|-----------|-----------|--------|-------|
| Tenzir | security-data | ✅ Running | Connected to app.tenzir.com (node: home_lab) |
| Tenzir PVCs | security-data | ✅ Bound | /var/lib/tenzir, /var/log/tenzir |
| Fluent Bit | security-data | ✅ Running | DaemonSet forwarding logs to Tenzir (master node only) |
| SIEM | security-data | ⏳ Research | Need lightweight option |

### Tasks

#### Week 9-10: OCSF Schema Deep Dive
- [x] Study OCSF schema structure and event classes
- [ ] Map common security events to OCSF categories:
  - Authentication events (class 3001)
  - Network activity (class 4001)
  - System activity (class 1001)
- [ ] Set up schema validation tooling

#### Week 11-12: Implementation
- [x] Deploy Tenzir for security data pipeline
- [x] Connect Tenzir to cloud platform (app.tenzir.com)
- [x] Test data import into Tenzir
- [x] Deploy Fluent Bit DaemonSet for security namespaces
- [x] Create Tenzir pipeline: `fluent-bit-server | import`
- [x] Fix log feedback loop (Exclude_Path for Fluent Bit's own logs)
- [x] Verify end-to-end pipeline: Fluent Bit → Tenzir → Tenzir Cloud UI
- [ ] Create OCSF transformation pipelines in Tenzir
- [ ] Research and deploy lightweight SIEM

### Tenzir Configuration
```yaml
# Current deployment resources
resources:
  requests:
    memory: 1Gi
    cpu: 200m
  limits:
    memory: 1536Mi  # 1.5Gi
    cpu: 1000m

# Ports
ports:
  - 5158   # Tenzir API
  - 24224  # Fluent Bit forward protocol
```

### Pending Tasks
- [ ] Build OCSF transformation pipelines
- [ ] Evaluate lightweight SIEM options:
  - Wazuh
  - Security Onion
  - Grafana + Loki with alerting rules

### Resources
- [OCSF GitHub Repository](https://github.com/ocsf/ocsf-schema)
- [OCSF Documentation](https://schema.ocsf.io/)
- [Tenzir Documentation](https://docs.tenzir.com/)
- AWS Security Lake OCSF implementation examples

---

## Phase 4: Penetration Testing Lab (Weeks 13-16)

### Objectives
- Deploy intentionally vulnerable applications
- Set up isolated attack/defense environments
- Practice common penetration testing techniques

### Tasks

#### Week 13-14: Vulnerable Applications
- [x] Create Kubernetes manifests for all targets (dvwa, juice-shop, webgoat, kali)
- [x] Create network isolation policies (namespace isolation + DNS allowance)
- [x] Create resource quota for vuln-lab namespace
- [x] Create Ansible deploy.yml playbook
- [ ] Run deploy playbook and verify all pods Running
- [ ] Complete DVWA first-time setup (visit /setup.php, create database)
- [ ] Register WebGoat user and explore lessons

```yaml
# Example: Isolated namespace for vulnerable apps
apiVersion: v1
kind: Namespace
metadata:
  name: vuln-lab
  labels:
    environment: isolated
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-vuln-lab
  namespace: vuln-lab
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: attacker-workstation
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: vuln-lab
```

#### Week 15-16: Penetration Testing Practice
- [ ] Set up Kali Linux tools container
- [ ] Practice OWASP Top 10 vulnerabilities
- [ ] Document findings in structured reports
- [ ] Correlate attacks with OCSF-normalized logs

### Tools to Deploy
| Tool | Purpose |
|------|---------|
| DVWA | Web application vulnerabilities |
| Juice Shop | Modern web app security |
| Metasploitable | System-level exploitation |
| WebGoat | Security training |
| Kali Linux | Attack tooling |

### Resources
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [HackTheBox](https://www.hackthebox.com/) for additional practice
- [TryHackMe](https://tryhackme.com/) learning paths

---

## Phase 5: Zero Trust Architecture (Weeks 17-20)

### Objectives
- Implement service mesh with mTLS
- Deploy policy-based access control
- Build identity-aware security

### Tasks

#### Week 17-18: Service Mesh Foundation
- [ ] Deploy Istio or Linkerd on K3s
- [ ] Enable automatic mTLS between services
- [ ] Configure strict PeerAuthentication policies

```yaml
# Istio strict mTLS policy
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
# Authorization policy example
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Deny all by default
```

#### Week 19-20: Zero Trust Policies
- [ ] Implement least-privilege network policies
- [ ] Deploy OPA/Gatekeeper for policy enforcement
- [ ] Set up workload identity (SPIFFE/SPIRE)
- [ ] Create microsegmentation between services

### Zero Trust Principles to Implement
1. **Never trust, always verify** - All traffic authenticated
2. **Least privilege access** - Minimal required permissions
3. **Assume breach** - Segment and monitor everything
4. **Continuous verification** - Real-time policy enforcement

### Resources
- [NIST Zero Trust Architecture (SP 800-207)](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [Istio Security Documentation](https://istio.io/latest/docs/concepts/security/)
- [SPIFFE/SPIRE Documentation](https://spiffe.io/docs/)

---

## Phase 6: AI-Powered Security with NVIDIA Morpheus (Weeks 21-24)

### Objectives
- Understand Morpheus architecture
- Build GPU-accelerated security pipelines
- Implement ML-based threat detection

### Prerequisites
> **Note**: Morpheus requires NVIDIA GPU. Options:
> - Cloud GPU instances (AWS, GCP, Azure)
> - NVIDIA Jetson for edge deployment
> - Future Mac Mini with eGPU setup

### Tasks

#### Week 21-22: Morpheus Fundamentals
- [ ] Study Morpheus architecture and components
- [ ] Set up development environment (Docker/cloud)
- [ ] Run example pipelines from Morpheus GitHub
- [ ] Understand RAPIDS and cuDF for data processing

#### Week 23-24: Security Use Cases
- [ ] Implement Digital Fingerprinting pipeline
- [ ] Build Sensitive Information Detection (SID)
- [ ] Create Phishing Detection workflow
- [ ] Integrate with OCSF-normalized data from Phase 3

### Morpheus Pipeline Architecture
```
[Data Source] → [Morpheus Pipeline] → [Detection/Classification] → [Alert/Response]
     ↓                  ↓                        ↓
   Logs/PCAP      GPU-Accelerated ML        OCSF Events
   Netflow        RAPIDS DataFrames         Prometheus Metrics
   OCSF Events    Triton Inference          Grafana Alerts
```

### Resources
- [NVIDIA Morpheus GitHub](https://github.com/nv-morpheus/Morpheus)
- [Morpheus Documentation](https://docs.nvidia.com/morpheus/)
- [RAPIDS Documentation](https://rapids.ai/)

---

## Hardware Considerations

### Current Setup (Sufficient for Phases 1-5)
- Mac Mini M4 cluster with K3s
- Thunderbolt bridge networking
- Local storage

### Future Additions for Phase 6
| Option | Cost | Notes |
|--------|------|-------|
| Cloud GPU | $1-3/hr | Best for learning, no upfront cost |
| NVIDIA Jetson Orin | ~$500-2000 | Edge AI, good for lab |
| eGPU Enclosure + GPU | $500-1500+ | Requires Thunderbolt, compatibility varies |

---

## Learning Resources Summary

### Books
1. "The Web Application Hacker's Handbook" - Stuttard & Pinto
2. "Kubernetes Security" - Rice & Shaw
3. "Zero Trust Networks" - Gilman & Barth
4. "Prometheus: Up & Running" - Brazil

### Certifications to Consider
- CompTIA Security+
- OSCP (Offensive Security Certified Professional)
- CKS (Certified Kubernetes Security Specialist)
- GIAC certifications

### Online Platforms
- HackTheBox
- TryHackMe
- PentesterLab
- Kubernetes Goat

---

## Progress Tracking

### Phase Completion Checklist
- [x] Phase 1: Observability Foundation ✅
- [x] Phase 2: Telemetry & Logging ✅
- [~] Phase 3: Security Data Normalization (Fluent Bit pipeline verified; OCSF, SIEM pending)
- [~] Phase 4: Penetration Testing Lab (manifests created; deploy pending)
- [ ] Phase 5: Zero Trust Architecture
- [ ] Phase 6: AI-Powered Security (future - requires GPU)

### Monthly Review Questions
1. What did I learn this month?
2. What challenges did I face?
3. What would I do differently?
4. What are my goals for next month?

---

## Next Steps (Current Priority)

1. **Build OCSF transformation pipelines** in Tenzir — normalize raw logs to OCSF schema
2. **Research and deploy lightweight SIEM** (Wazuh or Grafana+Loki alerting rules)
3. **Deploy vulnerable apps** (DVWA, Juice Shop) to generate security-relevant logs for Phase 4
4. **Wire OTel → Tenzir** for security namespace log routing (currently going to debug exporter)

### Key Files & Playbooks

| Component | Deploy Playbook | Values/Manifests |
|-----------|-----------------|------------------|
| Monitoring | `kubernetes/apps/monitoring/deploy.yml` | `values/prometheus-stack.yml` |
| Telemetry | `kubernetes/apps/telemetry/deploy.yml` | `values/loki-stack.yml`, `values/otel-collector.yml` |
| Security Data | `kubernetes/apps/security-data/deploy.yml` | `manifests/tenzir-*.yaml` |

### Quick Reference

```bash
# Check all pods
kubectl get pods -A

# SSH tunnel for services
ssh -L 3000:192.168.64.2:30300 -L 9090:192.168.64.2:30090 homelab@192.168.1.118

# Access Tenzir UI
open https://app.tenzir.com
```
