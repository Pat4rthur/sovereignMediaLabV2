# sovereignMediaLabV2
Transforming a functional ARR homelab into a segmented, monitored, and incident-aware Security Operations Center (SOC) portfolio environment.

---

## Executive Overview

**Objective:**  
Convert an operational ARR homelab into a documented SOC-style environment with centralized logging, detection engineering, and incident response simulation.

**Outcome:**  
A fully instrumented multi-container lab demonstrating:
- SIEM deployment and agent-based telemetry collection
- Custom detection rule engineering
- Internal threat simulation and post-compromise analysis
- Secure remote access via VPN segmentation
- Hardening aligned with CIS benchmarks

---

## Environment Architecture

The lab is built on a Proxmox hypervisor hosting a segmented LXC container network.

**Core components:**
- 9× LXC containers (ARR stack + supporting services)
- Proxmox host (network bridge + NAT boundary)
- Wazuh SIEM (centralized log ingestion, detection, alerting)
- WireGuard VPN (restricted remote access layer)

**Security model:**
- UFW-based microsegmentation per container
- Default-deny inbound posture
- VPN-only administrative access
- Centralized monitoring via Wazuh agents

---

## Phase 1: Environment Documentation & Security Baseline

**Objective:** Establish a known-good security baseline across the existing homelab environment.

**Actions Taken:**
- Audited all 9 LXC containers for firewall status and configuration drift
- Identified and remediated inactive UFW rules on SABnzbd and Pi-hole
- Standardized firewall posture:
  - Default deny inbound
  - Allow outbound traffic
  - SSH restricted to Proxmox host subnet
  - Web UI access limited to private network
- Produced initial network segmentation diagram

**Key Learning:**
- Actual system state often diverges from documented configuration
- Microsegmentation provides lightweight but effective lateral movement control
- Baseline documentation is essential for later incident reconstruction

**Artifacts:**
- [Network Diagram](diagrams/network_architecture_v1.png)
- [UFW Rules Summary](firewall/ufw_rules_summary.txt)

---

## Phase 2: SIEM Deployment (Wazuh)

**Objective:** Deploy centralized SIEM for log aggregation and detection.

**Actions Taken:**
- Deployed Wazuh 4.11.0 via Docker Compose on WSL2
- Configured OpenSearch requirement (`vm.max_map_count`)
- Established RBAC via custom `lab-admin` account
- Resolved dashboard permission model via `run_as` configuration
- Verified full stack (Manager, Indexer, Dashboard) functionality

**Key Learning:**
- Wazuh requires both indexer-level and dashboard-level RBAC alignment
- Containerized SIEM deployments are highly reproducible for lab environments
- Initial configuration issues often stem from permission layering, not service failure

**Artifacts:**
- [Wazuh Dashboard Overview](wazuh/screenshots/wazuh_dashboard_overview.png)
- [Agent Status Page](wazuh/screenshots/wazuh_agents_page.png)
- [Docker Status](wazuh/docker_ps_output.txt)

---

## Phase 3: Agent Deployment & Log Collection

**Objective:** Deploy Wazuh agents across Proxmox and all LXC containers.

**Actions Taken:**
- Installed Wazuh agent on Proxmox host
- Bulk-deployed agents across 9 LXC containers via automation script
- Validated all agents reporting to SIEM
- Standardized log collection across system and application layers

**Key Learning:**
- Automation reduces configuration drift across containerized environments
- Agent consistency is critical for reliable detection coverage
- Initial deployment success does not guarantee full telemetry visibility

**Artifacts:**
- [Agent Deployment Script](scripts/install_wazuh_agents_lxc.sh)
- [All Agents Active](wazuh/screenshots/wazuh_agents_all_active.png)

---

## Phase 4: Log Enrichment & Application Monitoring

**Objective:** Extend visibility into ARR application-layer logs.

**Actions Taken:**
- Configured syslog and journald ingestion for ARR services
- Standardized service monitoring across containers
- Verified log forwarding from SABnzbd, Sonarr, Radarr, and Prowlarr

**Key Learning:**
- System logs and application logs require separate ingestion strategies
- Systemd unit name inconsistencies can break monitoring pipelines
- Journald provides richer telemetry than syslog for container services

**Artifacts:**
- [Sonarr Log Configuration](wazuh/agent_configs/sonarr_ossec.conf)
- [Journal Log Evidence](wazuh/agent_logs/logcollector_journal.png)

---

## Phase 5: Detection Engineering (Custom Rules)

**Objective:** Create detection logic for ARR-specific behavior anomalies.

**Actions Taken:**
- Developed custom Wazuh rules for:
  - Suspicious DNS queries (.xyz, .top)
  - Execution attempts in download directories
- Resolved XML parsing issues in Wazuh 4.11
- Validated rules using `wazuh-logtest`
- Confirmed live alert generation for file execution detection

**Key Learning:**
- Wazuh rule structure is sensitive to decoder assumptions
- Custom detection requires iterative validation using test tooling
- Application-layer visibility significantly improves detection fidelity

**Artifacts:**
- [Custom Rules File](wazuh/local_rules.xml)
- [Rule Validation Output](wazuh/screenshots/rule_100101_logtest.png)

---

## Phase 6: Vulnerability Detection

**Objective:** Enable continuous CVE monitoring across container fleet.

**Actions Taken:**
- Enabled Wazuh vulnerability detector module
- Configured Ubuntu OVAL feed integration
- Verified vulnerability scanning pipeline

**Key Learning:**
- Vulnerability detection is provider-driven, not automatic
- Initial sync delays are expected with OVAL feeds
- Continuous scanning provides baseline risk visibility

**Artifacts:**
- [Vulnerability Configuration](wazuh/ossec_vulnerability_config.xml)

---

## Phase 7: Secure Remote Access (WireGuard VPN)

**Objective:** Replace exposed service access with zero-trust remote connectivity.

**Actions Taken:**
- Deployed WireGuard (WG-Easy) for VPN management
- Restricted VPN routing to internal subnet only
- Verified UFW enforcement over VPN tunnel
- Blocked direct WAN exposure of service UIs

**Key Learning:**
- VPN routing must be explicitly constrained via AllowedIPs
- Network segmentation remains enforced over encrypted tunnels
- VPN does not bypass host-level firewall policy

**Artifacts:**
- [VPN Configuration](vpn/wg_easy_allowed_ips.png)
- [Access Test Evidence](vpn/vpn_sonarr_access.jpeg)

---

## Phase 8: Incident Response Simulation

**Objective:** Simulate a full post-compromise attack chain and validate detection coverage.

**Scenario:**
Compromised SSH credentials used to pivot through internal network, escalate privileges, and attempt persistence.

**Phases Simulated:**
1. Initial access via SSH brute-force
2. Internal reconnaissance via network scanning
3. Privilege escalation via sudo attempt
4. Root escalation via su attempt

**Outcomes:**
- All escalation attempts failed at OS level
- All phases detected via Wazuh (built-in rules)
- One telemetry gap identified (kernel log ingestion)
- MASQUERADE NAT affected initial attribution accuracy

**Key Learning:**
- Default SIEM rules were sufficient for detection
- Visibility gaps were the primary weakness, not detection logic
- Host-level logging was required to reconstruct network activity

**Artifacts:**
- [Full Incident Report](incident_response/IR_SABnzbd_Malware.md)

---

## Phase 9: Compliance Hardening (CIS Benchmarking)

**Objective:** Align container configuration with CIS Ubuntu 22.04 benchmarks.

**Actions Taken:**
- Mapped controls across all containers
- Applied baseline hardening (SSH, kernel params, services, permissions)
- Automated compliance deployment via bash script
- Documented scoping limitations (auditd constraints)

**Key Learning:**
- Compliance frameworks provide structure for security posture validation
- Automation ensures consistency across distributed systems
- Not all controls are technically applicable in containerized environments

**Artifacts:**
- [Compliance Matrix](compliance/compliance-matrix.md)
- [Hardening Script](compliance/cis-hardening-script.sh)

---

## Ethical Use Statement

This environment is strictly for educational and portfolio purposes.  
All testing data is synthetic or locally generated. No external systems were targeted.
