# Phase 4: Penetration Testing Lab

Intentionally vulnerable applications for security testing practice.

## Components (Planned)

| Component | Purpose | Status |
|-----------|---------|--------|
| DVWA | Web application vulnerabilities | Planned |
| Juice Shop | Modern OWASP Top 10 training | Planned |
| WebGoat | Interactive security lessons | Planned |
| Kali Tools | Penetration testing toolkit | Planned |

## Network Isolation

All vulnerable applications will be deployed in an isolated namespace with strict network policies:

- No egress to internet
- No access to production namespaces
- Only accessible from designated attacker workstation

## Safety Considerations

These applications are intentionally vulnerable. Ensure:
1. Network policies are in place before deployment
2. No exposure to external networks
3. Separate namespace with resource quotas
4. Monitoring enabled to observe attack patterns

## Prerequisites

- Phase 1-3 deployed for observability of attacks
- Network policies configured

## Resources

- [OWASP DVWA](https://github.com/digininja/DVWA)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [OWASP WebGoat](https://owasp.org/www-project-webgoat/)
