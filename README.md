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

## Phase 2: SIEM Deployment (Wazuh on Docker)

**Objective:** Deploy a fully functional Wazuh SIEM/XDR platform to monitor the Proxmox homelab environment, establish role‑based access control, and prepare for agent deployment.

**Environment:**
- **Host:** Windows 11 Pro (172.16.5.20)
- **Method:** Docker Compose (single‑node) on WSL2
- **Version:** Wazuh 4.11.0

**Actions Taken:**
- Configured WSL kernel parameter `vm.max_map_count=262144` for OpenSearch compatibility
- Cloned official Wazuh Docker repository and deployed full stack (Manager, Indexer, Dashboard)
- Created custom administrator user `lab-admin` with full RBAC permissions
- Resolved dashboard permission errors by enabling `run_as: true` in container configuration
- Verified dashboard access and module availability

**Key Learning:**
- Wazuh's internal user management requires both indexer‑level (`all_access` role duplication) and server‑level (`administrator` role mapping) permissions
- The `run_as` setting is required for non‑default admin accounts to assume full privileges in the dashboard
- Containerized SIEM deployment provides rapid, reproducible infrastructure suitable for lab and production environments

**Artifacts:**
- [Dashboard Overview](wazuh/screenshots/wazuh_dashboard_overview.png)
- [Agents Page (Pre‑Deployment)](wazuh/screenshots/wazuh_agents_page.png)
- [Docker Container Status](wazuh/docker_ps_output.txt)
- [RBAC Configuration for lab‑admin](wazuh/screenshots/lab_admin_roles.png)
- [run_as Fix Command](wazuh/run_as_fix.txt)
- [WSL Kernel Tuning](wazuh/wsl_sysctl.txt)

## Task 2.2: First Agent Deployment (Proxmox Host)

**Objective:** Deploy Wazuh agent on the Proxmox hypervisor to collect system-level telemetry and security events.

**Actions Taken:**
- Generated agent deployment command via Wazuh dashboard (DEB amd64, server `172.16.5.20`)
- Executed command on Proxmox host (`172.16.5.10`)
- Verified agent status active and logging to manager

**Verification:**
- Agent `pve` appears in Wazuh dashboard with status **Active**
- Agent log shows successful enrollment and data transmission

**Artifacts:**
- [Agents Page with pve Active](wazuh/screenshots/wazuh_agent_pve_active.png)
- [Agent Details View](wazuh/screenshots/wazuh_agent_pve_details.png)
- [Proxmox Agent Service Status](wazuh/agent_logs/proxmox_agent_status.txt)
- [Agent Log Sample](wazuh/agent_logs/proxmox_ossec_log_sample.txt)

## Task 2.3: Multi-Agent Deployment (LXC Containers)

**Objective:** Deploy Wazuh agents across all 9 LXC containers hosting the ARR media stack and supporting services.

**Actions Taken:**
- Created a bash script on the Proxmox host to loop through container IDs and install the Wazuh agent via the official quick‑install script
- Addressed missing dependencies (`lsb-release`) automatically within the script
- Verified all 10 agents (Proxmox host + 9 containers) are actively reporting to the manager

**Verification:**
- All 10 agents appear in Wazuh dashboard with status **Active**
- Agent logs confirm successful enrollment and data transmission

**Artifacts:**
- [Agents Page with All Containers Active](wazuh/screenshots/wazuh_agents_all_active.png)
- [LXC Installation Script](scripts/install_wazuh_agents_lxc.sh)
- [Sample Agent Log (Sonarr)](wazuh/agent_logs/sonarr_agent_log.txt)

- **Post-Update Recovery**: After a Windows Update restart, the Wazuh manager container may need to be restarted and agents may require re-enrollment if the manager's data volume is reset. See [Troubleshooting Guide](docs/troubleshooting.md) for resolution steps.
- **Port Conflict**: Windows may reserve port 55000. The stack uses port 56000 on the host to avoid this conflict.

## Task 2.4: Enable Container Log Monitoring (ARR Services)

**Objective:** Configure Wazuh agents on ARR LXC containers to forward
service logs from systemd journals and syslog to the Wazuh manager,
enabling detection of application-layer events.

**Actions Taken:**
- Edited `/var/ossec/etc/ossec.conf` on CT103 (SABnzbd), CT104 (Sonarr),
  CT105 (Radarr), and CT108 (Prowlarr) to add dual log sources:
  - Syslog monitoring: `<location>/var/log/syslog</location>`
  - Journald command: `journalctl -u <service> --no-pager -n 50` (60s interval)
- Restarted Wazuh agents on all modified containers
- Verified agent connectivity and logcollector status in agent logs

**Key Learning:**
- ARR services log primarily to systemd journal; Wazuh requires explicit
  command monitoring to ingest these logs
- Syslog monitoring captures `logger` test events and general system messages
- Service unit names vary (e.g., `sabnzbdplus` vs `sabnzbd`); verification
  with `systemctl list-units` is essential

**Artifacts:**
- [Agent Configuration Sample (Sonarr)](wazuh/agent_configs/sonarr_ossec.conf)
- [Agent Log Showing Journal Monitoring](wazuh/agent_logs/logcollector_journal.png)

## Task 2.5: Custom Rule Creation (ARR Anomaly Detection)

**Objective:** Develop custom Wazuh rules to detect suspicious behavior
in the ARR stack, specifically Prowlarr DNS queries to high-risk TLDs
(.xyz, .top) and SABnzbd file execution attempts.

**Actions Taken:**
- Created `local_rules.xml` on Wazuh manager with two custom rules:
  - Rule 100101 (Level 10): Prowlarr suspicious DNS request to .xyz/.top TLD
  - Rule 100102 (Level 12): SABnzbd download directory file execution attempt
- Resolved Wazuh 4.11 XML parsing issues by removing `<decoded_as>` tags and
  placing rules in decoder-agnostic group (`local,arr_suite`)
- Validated rule logic using `wazuh-logtest` on the manager container
- Triggered live alert for Rule 100102 from CT103; documented pipeline
  issue for Rule 100101 in troubleshooting log

**Key Learning:**
- Wazuh 4.11 rejects `<decoded_as>syslog</decoded_as>` in custom rules unless
  a corresponding custom decoder is defined
- `logger` test events appear with program name `root`, requiring rules to
  match on decoded message field without syslog group dependency
- Isolated rule validation with `wazuh-logtest` accelerates debugging and
  separates logic issues from pipeline problems

**Artifacts:**
- [Custom Rules Definition](wazuh/local_rules.xml)
- [Rule 100101 Logtest Validation](wazuh/screenshots/rule_100101_logtest.png)
- [Rule 100102 Live Alert](wazuh/screenshots/alert_100102_fired.png)
- [Troubleshooting: Agent Pipeline Issue](docs/troubleshooting.md#incident-6)

## Task 2.6: Vulnerability Detection (CVE Scanning)

**Objective:** Enable Wazuh's built-in vulnerability detector to continuously
scan all Ubuntu 22.04 LXC containers for known CVEs using Canonical's OVAL feed.

**Actions Taken:**
- Edited Wazuh Manager `ossec.conf` to enable the vulnerability-detector module
- Configured Canonical provider for Ubuntu Jammy (22.04) and Focal (20.04)
- Set scan interval to 1 hour with run-on-start enabled
- Restarted manager and verified module initialization in logs

**Key Learning:**
- Vulnerability detection is disabled by default and requires explicit
  provider configuration
- The Canonical provider pulls CVE data from OVAL feeds; initial database
  download may take 10–20 minutes
- Scan results appear under "Vulnerability Detection" in the Wazuh dashboard

**Artifacts:**
- [Vulnerability Detector Configuration](wazuh/ossec_vulnerability_config.xml)
- [Vulnerability Dashboard Overview](wazuh/screenshots/vulnerability_detector_enabled.png)
