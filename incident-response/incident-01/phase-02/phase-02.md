# Phase 2: Internal Reconnaissance – Port Scan & Service Enumeration

**Incident:** Incident‑01 – Credential Brute‑Force to Privilege Escalation Attempt
**Phase:** 2 of 4
**Date:** 2026‑04‑29 through 2026‑04‑30
**Analyst:** Sovereign Media Lab SOC
**Status:** Evidence captured; SIEM detection deferred to Phase 7 (Suricata IDS)

---

## Attack Description
After establishing a foothold on the **Sonarr** container (CT104, `172.16.5.74`) with the compromised credentials from Phase 1, the attacker pivoted to internal reconnaissance. From an interactive SSH session as `testuser`, they executed a targeted port scan against the **SABnzbd** container (CT103, `172.16.5.73`) using **Nmap 7.80**. The scan probed ports **22** (SSH) and **8989** (SABnzbd web UI) with the `-Pn` flag to bypass host discovery. The objective was to map accessible services and locate further targets within the private `172.16.5.0/24` subnet.

**Tools used:** Nmap 7.80
**Source host:** CT104 (`172.16.5.74`, container `sonarr`)
**Target host:** CT103 (`172.16.5.73`, container `sabnzbd`)
**Scanned ports:** 22 (open), 8989 (filtered by UFW)

## Log Evidence (Raw)
Unprivileged LXC containers do not surface UFW kernel blocks to the container’s own log files. To capture the reconnaissance traffic, I placed a temporary `iptables` LOG rule directly on the **Proxmox host** (`172.16.5.10`), which sees all bridge traffic:

`iptables -I FORWARD -s 172.16.5.0/24 -j LOG --log-prefix "FW-FORWARD-SCAN: " `


With the LOG rule active, I re‑ran the scan from CT104 and captured live kernel output via `journalctl -k -f`. The following entries show the attacker’s SYN packets crossing the Proxmox bridge from `SRC=172.16.5.74` to `DST=172.16.5.73` on the exact ports targeted:

`Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 ... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=22 ... SYN`

`Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 ... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=8989 ... SYN`


**Attribution note:** The MASQUERADE rule documented in Phase 1 remained active during the scan. However, because the `iptables` LOG rule fires in the FORWARD chain *before* the NAT POSTROUTING table rewrites source addresses, the true attacker IP (`172.16.5.74`) was preserved. This was a critical forensic detail: without it, the scan would have appeared to originate from the Proxmox host itself.

The complete filtered evidence is preserved in the artifact file linked below.

**Full evidence file:** [Filtered kernel log extract](artifacts/phase-02-scan-evidence.txt)

## Wazuh Alerts Triggered
- **No alerts were generated** for the port scan activity.

During the scan window, the Proxmox host’s Wazuh agent (`pve`, agent ID `007`) logged only routine events: rootcheck anomalies (rule 510) and authentication successes (rules 5501, 87203). No `FW‑FORWARD‑SCAN` messages ever reached the SIEM.

## Investigation Steps

### 1. Alert Triage
I filtered the Wazuh Security Events dashboard by `agent.name: pve` for the time window `2026‑04‑29 12:22–12:26 UTC`. The scan window was completely silent in the SIEM — no new rules fired, no spike in event volume. This immediately signaled a detection gap: either the logs weren’t being collected, or they weren’t being parsed.

### 2. Host‑Level Confirmation
While the SIEM was silent, I confirmed the attack actually occurred by examining the Proxmox host’s kernel ring buffer directly. Running `journalctl -k -f` during a second scan produced the `FW‑FORWARD‑SCAN` entries shown above. This proved beyond doubt that the compromised Sonarr container was actively scanning the internal network — the evidence simply wasn’t reaching Wazuh.

### 3. Detection Engineering: Closing the Gap (Unsuccessful)
What followed was a multi‑hour effort to route kernel logs into the Wazuh pipeline. All attempts are documented in full in `docs/troubleshooting.md`. In summary:

| Method | Outcome |
|--------|---------|
| Add `<localfile>` for `journald` to the `pve` agent | Agent sent only rootcheck events; no kernel messages appeared |
| Switch `<localfile>` to `/dev/kmsg` | Same result — no kernel messages in Wazuh |
| Install `rsyslog`, configure `kern.* → /var/log/kern.log`, point agent at the file | `kern.log` populated correctly; agent still did not ship the lines |
| Attempt custom rule 100103 with multiple XML variants | Manager crashed repeatedly; reverted to clean `local_rules.xml` via Docker |

Each attempt was verified: the kernel logs existed on the host, the agent was alive and communicating, but the logs never transited to the manager. The root cause appears to be a combination of the Proxmox LXC architecture, the double‑NAT environment, and the specific way the `iptables` LOG target interacts with the kernel’s logging subsystem — a limitation of the current lab design.

### 4. Evidence Preservation
While the SIEM gap remains, the raw evidence is preserved in a filtered artifact (`phase-02-scan-evidence.txt`) containing only the scan‑relevant `FW‑FORWARD‑SCAN` lines. This allows manual correlation and serves as source material for the upcoming Suricata integration.

### 5. Documentation & Remediation Path
The full troubleshooting history, configuration attempts, and the clean rule XML that could not be deployed are documented in `docs/troubleshooting.md`. The permanent fix is deferred to **Phase 7 (Suricata IDS)** of the project roadmap, which will provide native network visibility and natively integrate with Wazuh’s Suricata module — no custom kernel log parsing required.

---

## Conclusion
The attacker successfully performed internal reconnaissance from a compromised container, demonstrating that the blast radius extends well beyond the initial foothold. Although the SIEM did not automatically detect the scan, the combination of a temporary `iptables` LOG rule and direct kernel log inspection allowed me to:

- Confirm the reconnaissance activity definitively
- Attribute it to the compromised host (`172.16.5.74`)
- Preserve forensic evidence
- Identify and thoroughly document a SIEM visibility gap
- File a concrete remediation plan (Phase 7) that will permanently close the gap

This mirrors a real‑world SOC workflow: the analyst detects a blind spot, exhausts immediate remediation options, preserves evidence manually, and escalates to detection engineering with a clear path forward.

**Containment Actions Taken:**
- Retained the temporary `iptables` LOG rule for continued host‑level visibility
- Preserved filtered kernel log evidence in the incident artifacts
- Documented the full troubleshooting history in `docs/troubleshooting.md`
- Left the `testuser` account and SSH access active to continue monitoring attacker behavior (to be revoked after the full incident lifecycle)

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Discovery | Network Service Scanning | T1046 |
| Discovery | System Network Configuration Discovery | T1016 |

## Artifacts
- [Filtered kernel log evidence of scan](artifacts/phase-02-scan-evidence.txt)
- [Wazuh dashboard – absence of scan alerts](artifacts/phase-02-wazuh-no-alerts.png)
