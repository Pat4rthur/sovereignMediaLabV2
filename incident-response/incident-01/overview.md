# Incident 01 — Credential Brute-Force to Privilege Escalation Attempt

**Date:** 2026-04-27 to 2026-04-30  
**Severity:** Medium (contained)  
**Status:** Closed — full attack chain detected and contained, no privilege escalation achieved  

---

## Executive Summary

This incident documents a full post-compromise attack chain executed against the **Sonarr container** within a segmented homelab environment, simulating a real-world intrusion scenario from initial access through multiple privilege escalation attempts.

The attacker gained [initial access via a successful SSH credential brute-force attack](phase-01/phase-01.md), then proceeded to conduct [internal reconnaissance](phase-02/phase-02.md) and attempt multiple privilege escalation techniques, including [sudo‑based account creation](phase-03/phase-03.md) and [direct `su` authentication to root](phase-04/phase-04.md).

Across all phases of the attack, defensive controls either:
- prevented execution at the operating system level, or  
- generated alerts via built-in Wazuh detection rules once logging was correctly configured  

No custom detection rules were required to identify attacker behavior.

---

## Key Outcomes

- **Initial Access Achieved:** Weak SSH credentials allowed successful login to a low-privilege account.
- **Internal Reconnaissance Detected (Manually):** Network scanning activity was confirmed at the host level, but initially exposed a SIEM ingestion gap for kernel-level logs.
- **Privilege Escalation Attempts Blocked:** Both `sudo` and `su` escalation paths were attempted and denied by system authentication and privilege controls.
- **Detection Coverage Validated:** Once log collection was corrected, all privilege escalation attempts were detected using built-in Wazuh rules.
- **Detection Gap Identified and Resolved:** A missing authentication log source (`/var/log/auth.log`) was identified mid-incident and remediated, restoring full visibility.

---

## Security Posture Assessment

This incident validated a layered defense model composed of:

- SSH authentication controls (initial access prevention failure point)
- Linux privilege separation (sudoers / root authentication controls)
- SIEM-based detection (Wazuh built-in rule coverage)
- Host-level logging and manual forensic validation during telemetry gaps

While endpoint controls successfully prevented escalation, the investigation also revealed a **monitoring gap affecting internal network reconnaissance visibility**, which is being addressed through planned deployment of Suricata IDS.

---

## Incident Significance

This case demonstrates a complete and realistic attack lifecycle within a controlled environment:

- The attacker adapted across multiple escalation techniques after repeated failures  
- Detection was achieved using mostly out-of-the-box SIEM rules  
- A temporary telemetry failure was identified and corrected during active investigation  
- The full attack chain was reconstructed without reliance on external tooling or post-incident log recovery  

The primary takeaway is not the success of detection, but the **identification and remediation of visibility gaps during an active security investigation**, which reflects real-world SOC operations.

---

## Planned Remediation

- Deployment of **Suricata IDS (Phase 7)** to provide network-level visibility independent of host logging configuration
- Standardization of authentication log ingestion across all endpoints
- Enforced SSH key-based authentication to eliminate password brute-force exposure

---

## Detailed Reports

- [Phase 1 – SSH Brute-Force Attack (Initial Access)](phase-01/phase-01.md)
- [Phase 2 – Internal Reconnaissance & Port Scan](phase-02/phase-02.md)
- [Phase 3 – Unauthorized sudo Attempt](phase-03/phase-03.md)
- [Phase 4 – su to Root Attempt](phase-04/phase-04.md)
