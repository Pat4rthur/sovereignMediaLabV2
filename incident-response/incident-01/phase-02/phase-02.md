# Phase 2: Internal Reconnaissance – Port Scan & Service Enumeration

**Incident:** Incident‑01 – Credential Brute‑Force to Privilege Escalation Attempt  
**Phase:** 2 of 4  
**Date:** 2026‑04‑29  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Contained – Detection gap identified, engineering ticket filed

---

## Attack Description
Using the compromised credentials (`testuser:password123`) obtained in Phase 1, the attacker logged into the **Sonarr** container (CT104, `172.16.5.74`) and executed a network port scan against the **SABnzbd** container (CT103, `172.16.5.73`). The scan targeted ports 22 (SSH) and 8989 (SABnzbd web UI) using `nmap -Pn`. The intention was to map accessible services and identify further targets within the private 172.16.5.0/24 subnet.

**Tools used:** Nmap 7.80  
**Source host:** CT104 (`172.16.5.74`)  
**Target host:** CT103 (`172.16.5.73`)

## Log Evidence (Raw)
Because UFW logging inside unprivileged LXC containers does not reliably surface kernel‑level blocks, I placed a temporary `iptables` LOG rule on the Proxmox host (`172.16.5.10`) to capture forwarded packets crossing the bridge:
`iptables -I FORWARD -s 172.16.5.0/24 -j LOG --log-prefix "FW-FORWARD-SCAN:`

I then re‑ran the scan from CT104 and captured the live kernel output via `journalctl -k -f`. The following entries show the reconnaissance traffic from `SRC=172.16.5.74` to `DST=172.16.5.73` with SYN flags on the scanned ports:

`Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 MAC=... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=22 ... SYN`

`Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 MAC=... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=8989 ... SYN
...`

*Note:* The MASQUERADE rule documented in Phase 1 remained active during the scan; however, the LOG rule captured the true source IP (`172.16.5.74`) because it examined packets before the NAT table rewrote the source address. This proved invaluable for attribution.

**Full evidence file:** [Kernel log extract](artifacts/phase-02-scan-evidence.txt)

## Wazuh Alerts Triggered
- **No alerts were generated** for the port scan activity.

The Proxmox host’s Wazuh agent (`pve`) logged only routine authentication events during the scan window (rules 87203, 5501). No kernel‑forward messages appeared in the SIEM because the agent is not currently configured to monitor the kernel log.

## Investigation Steps

### 1. Alert Triage
I opened the Wazuh Security Events dashboard and filtered by `agent.name: pve` for the time window `2026‑04‑29 12:22–12:26 UTC`. The expected spike in scan‑related alerts was absent. This immediately raised a detection‑engineering question.

### 2. Host‑Level Investigation
To confirm that the attack actually occurred, I examined the Proxmox host’s kernel ring buffer using `journalctl -k -f` while re‑running the scan. The `FW-FORWARD-SCAN` entries provided definitive proof of reconnaissance activity originating from the compromised Sonarr container.

### 3. SIEM Visibility Gap
I compared the host‑level evidence with the Wazuh console. The kernel lines were not ingested because the Proxmox agent lacks a `<localfile>` stanza for `/var/log/kern.log` and no custom rule exists to parse the `FW-FORWARD-SCAN` prefix. This is a classic blind spot in containerized monitoring environments.

### 4. Documentation & Handoff
I documented the gap, the temporary LOG rule, and the recommended Wazuh configuration (agent localfile + custom rule 100103) in the lab’s central troubleshooting document.

**Reference:** [Troubleshooting – Detection Gap: Proxmox Kernel Forward Logs](../../../docs/troubleshooting.md#detection-gap-proxmox-kernel-forward-logs-not-ingested-by-wazuh)

This mirrors a real‑world incident workflow: the SOC analyst identifies a coverage gap, files a ticket with detection engineering, and preserves the evidence in the meantime.

## Conclusion
The attacker successfully performed internal reconnaissance from a compromised container, proving the blast radius extends beyond the initial foothold. Although the SIEM did not automatically detect the scan, the combination of a temporary `iptables` LOG rule and direct kernel log inspection allowed me to confirm the activity, attribute it to the compromised host, and document the visibility gap for remediation.

**Containment Actions Taken:**
- Retained the temporary `iptables` LOG rule to ensure continued visibility until permanent Wazuh monitoring is in place.
- Filed detection‑engineering ticket in `docs/troubleshooting.md`.
- Left the `testuser` account active and the SSH rule in place to allow continued monitoring of attacker behavior (will be revoked after the full incident lifecycle completes).

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Discovery | Network Service Scanning | T1046 |
| Discovery | System Network Configuration Discovery | T1016 |

## Artifacts
- [Kernel log evidence of scan](artifacts/phase-02-scan-evidence.txt)
- [Wazuh dashboard – absence of scan alerts](artifacts/phase-02-wazuh-no-alerts.png)
- [Live journalctl output showing SYN packets](artifacts/phase-02-live-scan.png)
