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

## Incident 4: Custom Rules Validated but Live Alerts Not Firing from Agents

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

## Incident 5: Custom Alert Not Firing Despite Correct Rule Configuration

**Date:** 2026-04-16

**Symptom:** Custom rule 100102 (SABnzbd file execution) was loaded, but simulated test events via `logger` produced no alerts in Security Events.

**Root Cause:** The Wazuh agent on CT103 was configured only to monitor the SABnzbd service journal. The `logger` command writes to `/var/log/syslog`, which was not being collected.

**Resolution:**
- Added `<localfile>` block pointing to `/var/log/syslog` in agent `ossec.conf`.
- Restarted agent; alert appeared within 15 seconds.

**Preventative Measure:** Include `/var/log/syslog` in baseline agent configuration for all LXC containers.

---

## Incident 6: Custom Rules Validated but Live Alerts Not Firing from Agents

**Date:** 2026-04-17

**Symptom:** Custom rule 100101 fired correctly in `wazuh-logtest`, but simulated events from CT108 (Prowlarr) did not generate alerts in the Dashboard. Agent showed connected and syslog monitoring enabled.

**Root Cause Investigation:**
- Rule logic confirmed via logtest (decoder `root` extracts message, rule matches).
- Manager archives (`archives.log`) empty despite `<logall>yes</logall>`.
- Manager logs showed persistent `wazuh-csyslogd` and `wazuh-dbd` configuration errors.

**Hypothesis:** Manager analysis pipeline partially impaired due to legacy daemon errors.

**Workaround:** Rule functionality was fully validated using `wazuh-logtest`, confirming detection logic is sound. Live agent pipeline issue documented for future resolution.

**Lessons Learned:**
- Isolate rule testing with `wazuh-logtest` early to separate logic from pipeline issues.
- In containerized Wazuh deployments, legacy daemon errors can subtly break log processing.

---

## Incident 7: Pi‑hole DNS Not Responding (Port 53 Filtered)

**Date:** 2026-04-19

**Symptom:** All devices using Pi‑hole (`172.16.5.72`) as DNS server failed to resolve domains. `nslookup` timed out; `nmap` showed port 53/tcp as `filtered`.

**Root Cause:** UFW on CT102 was blocking inbound DNS traffic. Additionally, the container was configured to use itself as its own DNS server (loop condition).

**Resolution:**
- Allowed port 53 (TCP/UDP) in UFW: `ufw allow 53`.
- Set Pi‑hole's container DNS to `1.1.1.1` via Proxmox host (`pct set 102 --nameserver 1.1.1.1`).
- Restarted Pi‑hole FTL and verified resolution locally and remotely.

**Preventative Measures:**
- Include UFW rule for port 53 in baseline Pi‑hole deployment.
- Always set container DNS to external resolver to avoid loop.

---

## Incident 8: New LXC Container Cannot Reach Internet

**Date:** 2026-04-19

**Symptom:** Freshly created CT100 could ping gateway ARP but not IP, while existing containers (CT104) worked normally.

**Root Cause:** Proxmox container network option `firewall=1` was enabled, applying host firewall to the container's virtual interface. The host firewall lacked rules to allow forwarding for the new container.

**Resolution:** Disabled Proxmox firewall for the container interface: `pct set 100 --net0 firewall=0`. Internet connectivity restored immediately.

**Preventative Measure:** When creating LXC containers for internal services, set `firewall=0` unless specific per‑container firewall rules are required.

---

## Incident 9: Docker Container Fails with Sysctl Permission Denied in LXC

**Date:** 2026-04-19

**Symptom:** `docker run --privileged` failed with `open sysctl net.ipv4.ip_unprivileged_port_start file: permission denied`.

**Root Cause:** The LXC container was unprivileged (`unprivileged: 1`), preventing Docker from modifying kernel parameters even with `--privileged`.

**Resolution:** Recreated CT100 as a privileged LXC container (`--unprivileged 0` at creation). Docker container then started successfully.

**Trade‑off:** Privileged LXC reduces isolation but is acceptable for a dedicated VPN container in a trusted homelab.

---

## Incident 10: VPN Connected but No Access to Homelab Services

**Date:** 2026-04-19

**Symptom:** WireGuard VPN tunnel established, but phone could not reach containers on `172.16.5.0/24`. `AllowedIPs` was correctly set to homelab subnet.

**Root Cause:** The client's IP address was mistakenly set to a LAN IP (`172.16.5.107/32`) instead of an address from the VPN tunnel subnet (`10.8.0.0/24`). WireGuard requires the client's virtual IP to be within the tunnel network.

**Resolution:** In WG‑Easy UI, edited client Address field to `10.8.0.2/32`. Traffic then flowed correctly via VPN container's NAT/forwarding rules.

**Preventative Measure:** Allow WG‑Easy to auto‑assign client IPs from the `10.8.0.0/24` pool. Manual addresses must be within that same subnet.

---

## Incident 11: WireGuard Handshake Failing Over Cellular

**Date:** 2026-04-19

**Symptom:** `wg show` displayed no handshake or transfer for the peer. Phone could not access LAN resources despite tunnel being "active."

**Root Cause:** WG‑Easy was configured with `WG_HOST=172.16.5.70` (private LAN IP). Cellular data cannot route to private IPs.

**Resolution:**
- Set `WG_HOST` to public IP/DDNS and forward UDP 51820 on router.
- Recreated client configuration with correct endpoint.

**Preventative Measure:** Always use a public endpoint (IP or DDNS) for production remote access VPNs.

---

## Incident 12: Pi‑hole Container Network Isolation

**Date:** 2026-04-20

**Symptom:** Pi‑hole (CT102) services were running, but the container could not ping gateway or internet. Wazuh agent showed disconnected.

**Root Cause:** Proxmox container network configuration had `firewall=1` enabled, blocking all traffic from the container.

**Resolution:** Set `firewall=0` in container network configuration (`pct set 102 --net0 firewall=0`) and rebooted. Internet connectivity restored; Wazuh agent reconnected.

**Preventative Measure:** Use `firewall=0` for LXC containers unless explicit host firewall rules are required; rely on UFW within the container for service‑level filtering.

## Incident 13: Detection Gap: Proxmox Kernel Forward Logs Not Ingested by Wazuh  
*(Raised during Incident‑01, Phase 2 – Internal Reconnaissance)*

**Symptom**  
During investigation of a suspected port scan from CT104 (`172.16.5.74`) to CT103 (`172.16.5.73`), the Proxmox host’s `kern.log` recorded detailed `FW-FORWARD-SCAN` entries (generated by a temporary `iptables -I FORWARD … -j LOG` rule). However, the Wazuh agent on the Proxmox host (`pve`) did not generate any alerts for these entries, leaving the scan invisible to the SIEM.

**Root Cause**  
The Wazuh agent’s `ossec.conf` on the Proxmox host does not currently monitor the kernel log source for the `FW-FORWARD-SCAN` prefix. No custom rule exists to flag repeated SYN packets from a single source to multiple ports as a potential port scan.

**Recommended Actions (for Detection Engineering)**

1. Add a `<localfile>` stanza to `/var/ossec/etc/ossec.conf` on the Proxmox host to monitor the kernel log.  
   *Example (adjust path/format to match your journald setup)*:  
   ```xml
   <localfile>
     <location>/var/log/kern.log</location>
     <log_format>syslog</log_format>
   </localfile>
  Then restart the Wazuh agent.

Create a custom Wazuh rule to detect potential internal port scans based on FW-FORWARD-SCAN entries.
Example rule (place in /var/ossec/etc/rules/local_rules.xml on the Wazuh manager):
  `<group name="local,proxmox,">
  <rule id="100103" level="10">
    <decoded_as>syslog</decoded_as>
    <description>Possible internal port scan detected (FW-FORWARD-SCAN with SYN to multiple ports)</description>
    <match>FW-FORWARD-SCAN</match>
    <regex>SRC=\S+ DST=\S+ .*SYN</regex>
    <frequency count="4" timeframe="30">$dstip</frequency>
    <same_source_ip />
      <mitre>
      <id>T1046</id>
      </mitre>
    </rule>
  </group>`

This rule fires when four or more FW-FORWARD-SCAN lines with SYN are seen from the same source IP to the same destination IP within 30 seconds, mapping to MITRE technique T1046 (Network Service Scanning).

Status
Gap documented for post‑incident remediation. The temporary iptables logging rule remains in place for testing and can be removed when the permanent Wazuh detection is in place.

Linked from
[Investigation Step “SIEM Visibility Gap”](/incident-response/incident-01/phase-02/phase-02.md)
