# Phase 2: Internal Reconnaissance – Port Scan & Service Enumeration

**Incident:** Incident-01 – Credential Brute-Force to Privilege Escalation Attempt  
**Phase:** 2 of 4  
**Date:** 2026-04-29 through 2026-04-30  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Evidence captured – Detection gap identified; remediation planned (Phase 7: Suricata IDS)

---

# Executive Summary

Following initial access obtained in Phase 1, the attacker conducted internal reconnaissance from the compromised **Sonarr** container (`172.16.5.74`) to identify additional targets within the `172.16.5.0/24` subnet.

A targeted Nmap scan against the **SABnzbd** container (`172.16.5.73`) was successfully captured at the host level using a temporary `iptables` logging rule on the Proxmox hypervisor. This provided definitive evidence of attacker-driven network discovery activity.

However, the scan generated **no corresponding alerts in Wazuh**, exposing a critical detection gap in network-level visibility. Multiple ingestion and parsing attempts confirmed that kernel-generated logs were not reaching the SIEM pipeline.

This phase demonstrates:
- Post-compromise reconnaissance behavior
- Manual evidence collection under SIEM blind spots
- Identification and escalation of a detection engineering gap
- Transition from reactive analysis to architectural remediation planning

---

# Severity & Impact

**Severity:** Medium  

**Impact:**  
The attacker successfully enumerated internal services from a compromised host, identifying accessible targets for potential lateral movement.

The absence of SIEM detection for this activity represents a **significant visibility gap**, allowing an adversary to map internal infrastructure without generating alerts. In a production environment, this would materially increase the likelihood of undetected lateral movement and privilege escalation.

---

# Phase Objective

This phase evaluated the SOC’s ability to:

- Detect internal reconnaissance originating from a compromised endpoint  
- Capture and validate network-level activity outside SIEM visibility  
- Investigate and document a logging and ingestion failure  
- Preserve forensic evidence and define a sustainable remediation path  

---

# Environment Overview

| System | Role | IP Address |
|---|---|---|
| CT104 – Sonarr | Compromised Host | 172.16.5.74 |
| CT103 – SABnzbd | Reconnaissance Target | 172.16.5.73 |
| Proxmox Host (pve) | Network Bridge / Logging Point | 172.16.5.10 |
| Wazuh Manager | SIEM Platform | Internal |

All inter-container traffic traverses the Proxmox `vmbr0` bridge. A temporary `iptables` LOG rule was deployed at this layer to capture forwarded packets.

---

# Attack Simulation

From an interactive SSH session as `testuser`, the attacker executed a targeted Nmap scan using **Nmap 7.80** with the `-Pn` flag to bypass host discovery.

**Targeted ports:**
- **22 (SSH)** – reported open  
- **8989 (SABnzbd Web UI)** – filtered by UFW  

This focused scan reflects realistic attacker behavior following initial access: identifying reachable services before expanding scope.

---

# MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|--------|-----------|----|
| Discovery | Network Service Scanning | T1046 |
| Discovery | System Network Configuration Discovery | T1016 |

---

# Detection & Telemetry

## Alerts Triggered

- **None**

No Wazuh alerts were generated for the port scanning activity.

During the scan window, the Proxmox host agent (`pve`, ID `007`) reported only routine activity (rootcheck events and authentication logs). No kernel-derived or network scan indicators were ingested.

This absence of telemetry indicates a failure in **log collection and/or parsing**, not a lack of observable activity.

---

# Timeline of Events

| Time (UTC) | Event |
|---|---|
| 04-29 12:04 | Initial Nmap scan executed from compromised host |
| 04-29 12:23–12:24 | `iptables` LOG rule deployed; scan re-run and captured |
| 04-29–04-30 | Multiple SIEM ingestion and parsing attempts performed |
| 04-30 | Detection gap confirmed; remediation deferred to Phase 7 |

---

# Log Evidence

Kernel-level logging on the Proxmox host captured the reconnaissance traffic in real time:

```text
Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 ... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=22 ... SYN
Apr 29 07:23:27 pve kernel: FW-FORWARD-SCAN: IN=vmbr0 OUT=vmbr0 PHYSIN=veth104i0 PHYSOUT=veth103i0 ... SRC=172.16.5.74 DST=172.16.5.73 ... DPT=8989 ... SYN
```

Because the LOG rule operates in the **FORWARD chain (pre-NAT)**, the true source IP (`172.16.5.74`) was preserved despite the MASQUERADE rule identified in Phase 1.

Full evidence:
- [Filtered kernel log evidence of scan](artifacts/phase-02-scan-evidence.txt)

---

# Investigation

## Alert Triage

Wazuh Security Events were reviewed for agent `pve` during the scan window. No anomalies, alert spikes, or scan-related events were observed.

The absence of alerts—despite confirmed malicious activity—indicated a **visibility failure rather than a detection failure**.

---

## Host-Level Validation

Direct inspection of the Proxmox kernel buffer (`journalctl -k -f`) during a repeated scan confirmed the presence of expected SYN traffic logs.

This established:
- The scan occurred as expected  
- The logging rule functioned correctly  
- The SIEM ingestion pipeline failed to capture the data  

---

## Detection Engineering Analysis

Multiple ingestion strategies were tested to route kernel logs into Wazuh. All attempts failed to produce usable SIEM telemetry.

| Method | Outcome |
|--------|---------|
| `<localfile>` with `journald` | No kernel logs ingested |
| `<localfile>` with `/dev/kmsg` | No kernel logs ingested |
| `rsyslog` → `/var/log/kern.log` | Logs written locally; not forwarded |
| Custom Wazuh rule (ID 100103) | Parsing failures / manager instability |

Despite successful local log generation, no configuration allowed reliable ingestion into Wazuh.

**Assessment:**  
The issue is likely caused by a combination of:
- Proxmox LXC architecture constraints  
- Kernel logging behavior of `iptables` LOG target  
- Limitations in Wazuh agent log collection for this data source  

Full troubleshooting details are documented in `docs/troubleshooting.md`.

---

## Evidence Preservation & Escalation

Given the inability to ingest logs into the SIEM, the investigation shifted to:

- Preserving raw kernel log evidence  
- Documenting the ingestion failure  
- Defining a long-term detection strategy  

The detection gap was escalated and formally addressed in the project roadmap.

**Resolution Path:**  
Deployment of **Suricata IDS (Phase 7)** to provide:
- Native network traffic visibility  
- Structured event output (EVE JSON)  
- Direct integration with Wazuh  

---

# Analyst Assessment

The attacker demonstrated the ability to perform internal reconnaissance from a compromised container, confirming that initial access can be leveraged to map internal services without requiring elevated privileges.

The most significant outcome of this phase is the identification of a **critical SIEM visibility gap**. While host-level evidence confirmed the attack, the absence of automated detection highlights a failure in monitoring coverage.

The decision to transition to Suricata rather than continue kernel log ingestion attempts reflects a shift from **tactical troubleshooting to strategic detection engineering**, prioritizing reliability and scalability.

---

# Containment Actions

- Retained the `iptables` LOG rule for interim visibility  
- Preserved all scan-related kernel logs as forensic artifacts  
- Documented detection engineering attempts and failure modes  
- Maintained attacker access to observe continued behavior in later phases  

---

# Recommendations

| Recommendation | Purpose |
|---|---|
| Deploy Suricata IDS (Phase 7) | Enable reliable network-level detection |
| Validate SIEM ingestion pipelines regularly | Prevent silent logging failures |
| Expand telemetry sources beyond kernel logs | Improve detection resilience |
| Maintain interim host-level logging | Preserve visibility during remediation |

---

# Key Findings

- Internal port scan successfully executed from compromised host  
- Reconnaissance activity definitively captured at host level  
- No SIEM alerts generated due to ingestion failure  
- Kernel log pipeline proved unreliable in this architecture  
- Detection gap documented and escalated with a defined remediation path  

---

# Artifacts

- [Filtered kernel log evidence of scan](artifacts/phase-02-scan-evidence.txt)  
- [Wazuh dashboard – absence of scan alerts](artifacts/phase-02-wazuh-no-alerts.png)
