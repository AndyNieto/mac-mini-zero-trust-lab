# Kubernetes Applications

Helm-based application deployments for the K3s home lab cluster. Organized by phase from the [Cybersecurity Lab Plan](../../docs/CYBERSECURITY_LAB_PLAN.md).

## Structure

```
apps/
├── monitoring/      # Phase 1: Observability (Prometheus, Grafana, Alertmanager)
├── telemetry/       # Phase 2: OpenTelemetry, Loki, distributed tracing
├── security-data/   # Phase 3: OCSF normalization, Vector pipelines
├── vuln-lab/        # Phase 4: Vulnerable apps for penetration testing
└── zero-trust/      # Phase 5: Service mesh, mTLS, policy enforcement
```

## Usage

Each app folder contains:
- `deploy.yml` - Ansible playbook to deploy the application
- `status.yml` - Ansible playbook to check deployment status
- `values/` - Helm values files for customization

### Deploy an application

```bash
# From project root
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/monitoring/deploy.yml
```

### Check status

```bash
ansible-playbook -i ansible/inventory/hosts.ini kubernetes/apps/monitoring/status.yml
```

## Phase Progress

- [ ] **Phase 1: Monitoring** - Prometheus, Grafana, Alertmanager
- [ ] **Phase 2: Telemetry** - OpenTelemetry, Loki, Tempo
- [ ] **Phase 3: Security Data** - OCSF schema, Vector, log normalization
- [ ] **Phase 4: Vuln Lab** - DVWA, Juice Shop, attack tools
- [ ] **Phase 5: Zero Trust** - Istio/Linkerd, mTLS, OPA policies
