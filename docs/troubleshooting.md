# Troubleshooting Log

This document records significant operational incidents and their resolutions.

## Incident 1: Agent Disconnection After Windows Update

**Date:** 2026-04-15  
**Symptom:** All Wazuh agents showed `Disconnected` after Windows 11 host rebooted for updates.  
**Root Cause:** Docker Desktop restarted the Wazuh manager container, but the agent enrollment records were held in a volume that experienced a state conflict, causing the manager to reject re-enrollment attempts with `Duplicate name` warnings.  
**Resolution Steps:**
1. Verified network connectivity from agent to manager (`nc -zv 172.16.5.20 1515` succeeded).
2. Stopped Wazuh stack: `docker compose down -v` (removed volumes to clear stale agent data).
3. Regenerated certificates: `docker compose -f generate-indexer-certs.yml run --rm generator`.
4. Restarted stack: `docker compose up -d`.
5. Restarted all agents from Proxmox host.
6. Agents successfully re-enrolled and became active.

**Preventative Measures:** None required for a homelab; in production, use persistent volume backups and monitor agent enrollment alerts.

---

## Incident 2: Port 55000 Reservation Conflict

**Date:** 2026-04-15  
**Symptom:** Wazuh manager container failed to start with error: `listen tcp 0.0.0.0:55000: bind: An attempt was made to access a socket in a way forbidden by its access permissions.`  
**Root Cause:** Windows Hyper‑V (used by WSL2) reserves a dynamic port range that includes `55000`, preventing Docker from binding to it.  
**Resolution Steps:**
1. Confirmed port was excluded: `netsh interface ipv4 show excludedportrange protocol=tcp`.
2. Adjusted Windows dynamic port range to start at `49152`:
   ```powershell
   netsh int ipv4 set dynamicportrange tcp start=49152 num=16384

## Incident 3: Permission Denied When Generating Certificates on Windows Filesystem

**Date:** 2026-04-15  
**Symptom:** Running `docker compose -f generate-indexer-certs.yml run --rm generator` failed with multiple `Permission denied` errors when attempting to write certificate files (`root-ca.key`, `wazuh.manager.pem`, etc.) to the `config/wazuh_indexer_ssl_certs/` directory. Additionally, attempting to remove the `config/` directory manually resulted in similar permission errors.  

**Root Cause:** The Wazuh Docker project was located on the Windows filesystem (accessible via `/mnt/c/Users/...`). Docker containers running under WSL2 cannot properly set Unix file ownership and permissions on Windows‑mounted drives, causing write operations to fail and leaving files with ownership that prevents normal user deletion.  

**Resolution Steps:**
1. Attempted to copy the project to the native WSL Linux filesystem:

`cp -r /mnt/c/Users/Freep/Downloads/Wazuh/wazuh-docker ~/`
This failed due to permission errors on the certificate files.

2. Removed the partial copy and used sudo to force deletion of the old Windows‑side directory (optional but clean):

`cd ~
sudo rm -rf wazuh-docker`

3. Performed a fresh clone of the Wazuh Docker repository directly into the WSL Linux filesystem:
`git clone https://github.com/wazuh/wazuh-docker.git -b v4.11.0 ~/wazuh-docker
cd ~/wazuh-docker/single-node`

4. Generated certificates successfully from the new location:
`docker compose -f generate-indexer-certs.yml run --rm generator`

5. Started the stack:
`docker compose up -d`

6. Restarted all agents from the Proxmox host to re‑enroll with the fresh manager.

Preventative Measure: Always store Docker‑managed project files (especially those requiring volume mounts with specific Unix ownership) within the WSL Linux filesystem (~/) rather than on Windows‑mounted drives (/mnt/c/). This ensures correct permission handling and avoids filesystem translation issues.

## Incident 6: Custom Rules Validated but Live Alerts Not Firing from Agents

**Date:** 2026-04-17

**Symptom:** Custom rule 100101 fires correctly in `wazuh-logtest`, but simulated events from CT108 (Prowlarr) do not generate alerts in the Wazuh Dashboard. Agent shows connected, syslog monitoring enabled, and network connectivity verified.

**Root Cause Investigation:**
- Rule logic confirmed via `wazuh-logtest` (decoder `root` extracts message, rule matches)
- Agent configuration correct (`/var/log/syslog` monitored, manager address 172.16.5.20)
- Network connectivity successful (`nc -vz 172.16.5.20 1514`)
- Manager archives (`archives.log`) empty despite `<logall>yes</logall>`
- Manager logs show persistent `wazuh-csyslogd` configuration errors from legacy daemons

**Hypothesis:** The manager's analysis pipeline is partially impaired due to unresolved `csyslogd` and `dbd` configuration errors, preventing full processing of incoming events.

**Workaround / Mitigation:**
- Rule functionality was fully validated using `wazuh-logtest`, confirming detection logic is sound.
- Agent-side configuration is correct and ready for future pipeline resolution.

**Lessons Learned:**
- Isolate rule testing with `wazuh-logtest` early to separate logic issues from pipeline issues.
- In containerized Wazuh deployments, legacy daemon errors can subtly break log processing even when core services appear running.
- Full pipeline validation requires end-to-end testing with archives enabled.

**Next Steps (Future Work):**
- Rebuild Wazuh manager container with a clean `ossec.conf` that explicitly disables all legacy daemons.
- Validate end-to-end alerting with a minimal test environment before scaling to all LXC agents.
