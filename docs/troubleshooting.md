# Troubleshooting Log

This document records operational issues encountered during lab development, including symptoms, root cause analysis, resolution steps, and preventative measures.

---

## Incident 1: Agent Disconnection After Windows Update

**Date:** 2026-04-15  
**Symptom:** All Wazuh agents showed `Disconnected` after host reboot.  

**Root Cause:**  
Docker Desktop restart caused Wazuh manager container state conflict. Existing agent enrollment data in persistent volumes caused duplicate registration rejection.

**Resolution:**
- Verified network connectivity between agents and manager
- Recreated Wazuh stack (`docker compose down -v`)
- Regenerated certificates using official generator container
- Restarted stack and re-enrolled all agents

**Preventative Measures:**  
In production: maintain persistent volume backups and monitor agent enrollment health alerts.

---

## Incident 2: Port 55000 Reservation Conflict

**Date:** 2026-04-15  
**Symptom:** Wazuh manager failed to bind to port 55000.

**Root Cause:**  
Windows Hyper-V reserved dynamic port range included 55000.

**Resolution:**
- Confirmed exclusion range via `netsh interface ipv4 show excludedportrange protocol=tcp`
- Adjusted dynamic port range to avoid conflict

**Preventative Measures:**  
Verify Windows reserved ports before deploying containerized services.

---

## Incident 3: Certificate Generation Failure on Windows Filesystem

**Date:** 2026-04-15  
**Symptom:** Certificate generation failed with `Permission denied` errors on Windows-mounted filesystem.

**Root Cause:**  
WSL2 Docker cannot properly handle Unix file permissions on `/mnt/c` filesystem.

**Resolution:**
- Migrated project into native WSL filesystem (`~/wazuh-docker`)
- Removed broken Windows-mounted copy
- Re-cloned repository and regenerated certificates successfully

**Preventative Measures:**  
All Docker-managed projects must reside inside WSL filesystem, not Windows mount points.

---

## Incident 4: Custom Rules Valid but No Live Alerts

**Date:** 2026-04-17  
**Symptom:** Rule 100101 validated in `wazuh-logtest` but no alerts generated in dashboard.

**Root Cause:**  
Wazuh manager pipeline issues due to legacy daemon configuration errors (`csyslogd`, `dbd`).

**Resolution:**
- No full resolution during incident window
- Confirmed rule logic is correct via `wazuh-logtest`
- Documented as pipeline-level issue, not rule-level failure

**Preventative Measures:**
- Use `wazuh-logtest` early to isolate rule logic from pipeline issues
- Validate manager health before scaling rule testing

---

## Incident 5: Missing Syslog Input for Custom Rule Trigger

**Date:** 2026-04-16  
**Symptom:** Rule 100102 did not fire on test execution events.

**Root Cause:**  
Agent was not configured to monitor `/var/log/syslog`.

**Resolution:**
- Added syslog localfile configuration to agent
- Restarted agent
- Verified alert generation

**Preventative Measures:**  
Include `/var/log/syslog` in baseline agent configuration.

---

## Incident 6: Duplicate Entry Removed
*(Merged into Incident 4 to avoid duplication)*

---

## Incident 7: Pi-hole DNS Failure (Port 53 Blocked)

**Date:** 2026-04-19  
**Symptom:** DNS resolution failure across network.

**Root Cause:**  
UFW blocked inbound DNS traffic and Pi-hole had self-referencing DNS configuration.

**Resolution:**
- Opened port 53 (TCP/UDP)
- Set external DNS resolver (1.1.1.1)
- Restarted Pi-hole service

**Preventative Measures:**
- Always allow DNS traffic in baseline firewall rules
- Avoid self-referential DNS configuration loops

---

## Incident 8: New LXC Container Cannot Reach Internet

**Date:** 2026-04-19  
**Symptom:** Container could not reach external network despite valid IP assignment.

**Root Cause:**  
Proxmox firewall enabled on container interface blocked forwarding.

**Resolution:**
- Disabled container firewall (`firewall=0`)
- Restored connectivity

**Preventative Measures:**  
Disable Proxmox firewall unless explicitly required per container.

---

## Incident 9: Docker Fails in Unprivileged LXC

**Date:** 2026-04-19  
**Symptom:** Docker failed due to sysctl permission errors.

**Root Cause:**  
Unprivileged LXC prevented kernel parameter modifications.

**Resolution:**
- Recreated container as privileged LXC
- Docker functionality restored

**Tradeoff:** Reduced isolation accepted for lab environment.

---

## Incident 10: WireGuard Connected but No Access

**Date:** 2026-04-19  
**Symptom:** VPN tunnel active but no LAN access.

**Root Cause:**  
Incorrect VPN client IP assignment outside tunnel subnet.

**Resolution:**
- Assigned client IP within `10.8.0.0/24`
- Connectivity restored

---

## Incident 11: WireGuard Handshake Failure

**Date:** 2026-04-19  
**Symptom:** No handshake observed on VPN peer.

**Root Cause:**  
VPN endpoint configured with private LAN IP instead of public address.

**Resolution:**
- Updated WG_HOST to public IP/DDNS
- Enabled UDP port forwarding
- Reissued client config

---

## Incident 12: Pi-hole Container Network Isolation

**Date:** 2026-04-20  
**Symptom:** Container lost all network connectivity.

**Root Cause:**  
Proxmox firewall blocked all container traffic.

**Resolution:**
- Disabled firewall for container interface
- Restored connectivity

---

## Incident 13: Wazuh Missing Kernel Forward Logs (Detection Gap)

**Date:** 2026-04-17  

**Symptom:**  
iptables FORWARD chain logs captured on Proxmox host were not ingested by Wazuh.

**Root Cause:**  
Wazuh agent unable to process kernel-level logs due to architecture limitations in Proxmox LXC + NAT + logging pipeline behavior.

**Attempts:**
- journald ingestion → no kernel events
- /dev/kmsg ingestion → no output
- rsyslog kernel forwarding → partial success but not ingested
- custom rule injection → manager instability

**Resolution:**
Deferred to Phase 7 (Suricata IDS) for proper network-layer visibility.

**Status:** Open (mitigated via manual logging + artifacts)

---

## Incident 14: Authentication Logging Gap on Sonarr Agent

**Date:** 2026-04-17  

**Symptom:** sudo events not appearing in SIEM.

**Root Cause:**  
Missing `/var/log/auth.log` ingestion configuration on agent.

**Resolution:**
- Added auth.log localfile configuration
- Restarted agent
- Verified immediate alert generation

---
