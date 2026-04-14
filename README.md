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

## Phase 2.2: First Agent Deployment (Proxmox Host)

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

## Phase 2.3: Multi-Agent Deployment (LXC Containers)

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
- [Sample Agent Log (Sonarr)](wazuh/agent-logs/sonarr_agent_log.txt)
