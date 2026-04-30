# Phase 1: SSH Brute-Force Attack

**Incident:** Incident-01 – Credential Brute-Force to Privilege Escalation Attempt  
**Phase:** 1 of 4  
**Date:** 2026-04-27  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Closed – Credential compromise confirmed and contained  

---

# Executive Summary

A simulated attacker successfully compromised a Linux endpoint via a dictionary-based SSH brute-force attack against a weak user account. Detection was achieved through Wazuh alerts correlating repeated authentication failures followed by a successful login event.

Initial investigation incorrectly attributed the attack source to the Proxmox hypervisor due to NAT translation. Further analysis identified a `MASQUERADE` rule that rewrote source IP addresses, obscuring the true attacker. Correlation of SIEM telemetry, host logs, and attacker tooling confirmed the originating system.

This phase validated:
- Detection of SSH brute-force activity via Wazuh  
- Log-based investigation and alert correlation  
- Timeline reconstruction of authentication events  
- Identification and resolution of network-based attribution issues  

---

# Severity & Impact

**Severity:** Medium  

**Impact:**  
Successful credential compromise of a Linux service account (`testuser`) via SSH. This level of access provides an entry point for lateral movement, privilege escalation, or persistence if left uncontained.

---

# Scenario Objective

This phase simulated credential-access activity to evaluate the environment’s ability to:

- Detect repeated SSH authentication failures  
- Identify successful unauthorized access  
- Investigate anomalous authentication telemetry  
- Accurately attribute attacker activity in the presence of network translation  

---

# Environment Overview

| System | Role | IP Address |
|---|---|---|
| CT104 – Sonarr | Target Endpoint | 172.16.5.74 |
| CT113 – Attacker | Simulated Threat Actor | 172.16.5.83 |
| Proxmox Host | NAT Gateway / Hypervisor | 172.16.5.10 |
| Wazuh Manager | SIEM Platform | Internal |

Authentication logs were collected via `journald` and forwarded to Wazuh by agent `008` (`sonarr`).

---

# Attack Simulation

A dictionary-based SSH brute-force attack was executed from the attacker container using **Hydra v9.2** against the `testuser` account on the Sonarr container.

The attack leveraged a small list of common weak credentials:

- `admin`  
- `123456`  
- `password`  
- `letmein`  
- `password123`  

After four failed attempts, authentication succeeded using `password123`, resulting in an interactive SSH session.

This activity emulates opportunistic brute-force attacks frequently observed against exposed SSH services.

---

# MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Password Guessing | T1110.001 |
| Lateral Movement | Remote Services: SSH | T1021.004 |
| Discovery | System Network Configuration Discovery | T1016 |

---

# Detection & Telemetry

## Alerts Triggered

| Rule ID | Description | Severity | Count |
|---|---|---|---|
| 5760 | `sshd: authentication failed` | Level 5 | 4 |
| 5501 | `PAM: Login session opened` | Level 5 | 1 |

Wazuh telemetry showed a burst of failed authentication attempts immediately followed by a successful login and session creation. This pattern is strongly indicative of automated brute-force activity rather than normal user behavior.

---

# Timeline of Events

| Time (UTC) | Event |
|---|---|
| 12:24:38 | Initial failed SSH authentication attempt |
| 12:24:38–12:24:39 | Multiple failed login attempts detected |
| 12:24:39 | Successful authentication for `testuser` |
| 12:24:39 | SSH session established |

---

# Log Evidence

Authentication logs captured via `journalctl -u ssh`:

```text
Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36428 ssh2
Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36438 ssh2
...
Apr 27 17:24:39 sonarr sshd[147449]: Accepted password for testuser from 172.16.5.10 port 36448 ssh2
Apr 27 17:24:39 sonarr sshd[147449]: pam_unix(sshd:session): session opened for user testuser(uid=1000) by (uid=0)
```

All events reported a source IP of **172.16.5.10** (Proxmox host), not the expected attacker system.

This discrepancy triggered deeper investigation.

---

# Investigation

## Alert Triage

Filtering Wazuh events by agent `sonarr` and rule `5760` revealed a concentrated spike of authentication failures followed immediately by a successful login event (`5501`). This sequence indicated likely credential compromise rather than benign login activity.

---

## Alert Analysis

Inspection of the Rule `5760` JSON payload showed:

- `srcip`: 172.16.5.10  
- `dstuser`: testuser  

The reported source IP did not match the known attacker system (`172.16.5.83`), suggesting network-level obfuscation or misattribution.

---

## Network Analysis

Review of the Proxmox host configuration identified the root cause of the discrepancy.

A NAT rule was actively rewriting outbound traffic:

```bash
iptables -t nat -L POSTROUTING -v -n
```

```text
MASQUERADE all -- * vmbr0 172.16.5.0/24 0.0.0.0/0
```

This rule forced all LXC container traffic to appear as originating from the hypervisor (`172.16.5.10`), masking the true source of the attack.

---

## Attribution Confirmation

Correlation across multiple data sources confirmed the true attacker identity:

- Hydra output from CT113 showed successful authentication  
- Timestamps aligned with Wazuh alerts and SSH logs  
- Authentication sequence matched observed SIEM telemetry  

**Conclusion:**  
- Actual attacker: `172.16.5.83`  
- Logged source (NAT): `172.16.5.10`  

---

# Analyst Assessment

The activity represents a successful SSH brute-force attack resulting in credential compromise of a weak account.

A key investigative challenge was introduced by NAT translation, which caused initial misattribution of the attack to the hypervisor. Accurate attribution required correlating endpoint logs, SIEM alerts, and attacker-side evidence.

Key observations:
- Weak passwords remain highly susceptible to automated attacks  
- Authentication telemetry provided sufficient data for detection and timeline reconstruction  
- Network address translation can significantly impact SIEM attribution accuracy  
- Multi-source correlation is critical when investigating anomalous telemetry  

---

# Containment Actions

- Locked the compromised `testuser` account  
- Removed the temporary `MASQUERADE` rule for subsequent phases  
- Documented NAT behavior and its impact on detection accuracy  
- Preserved logs and artifacts for analysis  

---

# Recommendations

| Recommendation | Purpose |
|---|---|
| Enforce strong password policies | Reduce brute-force success rate |
| Disable password-based SSH authentication | Prevent credential guessing attacks |
| Implement SSH key authentication | Strengthen access control |
| Deploy automated blocking (e.g., Fail2Ban) | Mitigate repeated login attempts |
| Review NAT visibility in logging pipelines | Improve attribution accuracy |

---

# Key Findings

- Confirmed dictionary-based SSH brute-force attack  
- Successful credential compromise via weak password  
- NAT configuration caused incorrect source attribution  
- Accurate identification required cross-source log correlation  

---

# Artifacts

- [Wazuh Security Events – 4×5760 + 1×5501](artifacts/events.png)
- [Rule 5760 JSON payload – srcip 172.16.5.10](artifacts/5760-json.json)
- [Hydra brute-force terminal output](artifacts/hydra-output.png)
- [Proxmox iptables MASQUERADE rule](artifacts/iptables-masquerade.png)
- [Threat Hunting report visualization](artifacts/threat-hunt.png)
- [Raw authentication log segment](artifacts/sshAuthLog.png)
