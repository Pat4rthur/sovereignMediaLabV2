# sovereignMediaLabV2
 Transforming a functional ARR homelab into a documented, monitored, and segmented Security Operations Center (SOC) portfolio piece.
## Phase 1: Environment Documentation & Security Baseline

**Objective:** Document existing Proxmox/ARR homelab and establish a known, hardened security baseline before deploying monitoring.

**Actions Taken:**
- Audited all 9 LXC containers for firewall status
- Discovered and remediated inactive UFW on SABnzbd (CT 103) and Pi-hole (CT 102)
- Standardized UFW rules: deny inbound, allow outbound, restrict SSH to Proxmox host only, limit web UI access to private subnet
- Created network architecture diagram using Draw.io, clearly separating management and application zones

**Key Learning:**
- Importance of verifying documented security posture against actual running configuration
- UFW microsegmentation as a lightweight zero‑trust layer for containerized services
- Network documentation as a prerequisite for effective monitoring and incident response

**Artifacts:**
- [Network Diagram](diagrams/network_architecture_v1.png)
- [UFW Rules Summary](firewall/ufw_rules_summary.txt)
