# Phase 3: Privilege Escalation Attempt – Unauthorized sudo

**Incident:** Incident-01 – Credential Brute-Force to Privilege Escalation Attempt  
**Phase:** 3 of 4  
**Date:** 2026-04-29  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Attempt blocked – Detection validated after log ingestion gap resolved  

---

# Executive Summary

Following internal reconnaissance in Phase 2, the attacker attempted to escalate privileges on the compromised **Sonarr** container by creating a new user account via `sudo adduser hacker`.

The attempt was blocked by the system’s sudo policy, as the compromised account (`testuser`) lacked the required privileges. However, initial execution of the command produced **no SIEM alerts**, revealing a critical log collection gap in the Wazuh agent configuration.

After enabling monitoring of `/var/log/auth.log`, the same activity immediately triggered a built-in Wazuh rule (5405) without requiring custom detection logic.

This phase demonstrates:
- Detection of unauthorized privilege escalation attempts via native SIEM rules  
- Identification and remediation of an agent-level logging gap  
- Correlation of attacker activity with authentication telemetry  
- Validation of defense-in-depth controls (OS policy + SIEM detection)  

---

# Severity & Impact

**Severity:** Medium  

**Impact:**  
The attacker attempted to create a persistent backdoor account (`hacker`) that would survive credential rotation and enable continued access.

Although the attempt was blocked, the initial absence of SIEM visibility represents a **critical detection gap**. Without remediation, privilege escalation attempts could occur without alerting, delaying response and increasing risk of successful compromise.

---

# Phase Objective

This phase evaluated the SOC’s ability to:

- Detect privilege escalation attempts via sudo  
- Identify and resolve SIEM log collection gaps  
- Correlate attacker commands with alert telemetry  
- Validate enforcement of least-privilege controls  

---

# Environment Overview

| System | Role | IP Address |
|---|---|---|
| CT104 – Sonarr | Compromised Host | 172.16.5.74 |
| Wazuh Manager | SIEM Platform | Internal |

The Sonarr container runs Ubuntu 22.04 with CIS hardening applied. The `testuser` account is a standard unprivileged user with no sudo group membership and no explicit sudoers entries.

Authentication logs are written to `/var/log/auth.log` and must be explicitly monitored by the Wazuh agent.

---

# Attack Simulation

From the established SSH session, the attacker attempted to create a new user account:

```bash
sudo adduser hacker
```

The attacker supplied the known password for `testuser` when prompted. Authentication succeeded, but authorization failed due to lack of sudo privileges.

Earlier attempts using `sudo -n` failed silently from a detection perspective, as they did not reach the authorization stage required to generate a `user NOT in sudoers` log entry.

---

# MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Privilege Escalation | Sudo and Sudo Caching | T1548.003 |
| Persistence | Create Account (attempted) | T1136.001 |

---

# Detection & Telemetry

## Alerts Triggered

- **Rule 5405** — `Unauthorized user attempted to use sudo` (Level 5)

The alert was generated only after `/var/log/auth.log` monitoring was enabled on the Sonarr Wazuh agent.

This confirms:
- Detection logic was functioning as expected  
- The gap existed in **log collection**, not rule coverage  

---

# Timeline of Events

| Time (UTC) | Event |
|---|---|
| 04-29 15:09 | Initial `sudo -n` attempts; no SIEM alerts |
| 04-29 15:17 | Logging gap identified; `/var/log/auth.log` added to agent config |
| 04-29 15:17 | Wazuh agent restarted |
| 04-29 15:27 | `sudo adduser hacker` executed; Rule 5405 triggered |

---

# Log Evidence

The following entry was recorded in `/var/log/auth.log`:

```text
Apr 29 15:27:04 sonarr sudo[163686]: testuser : user NOT in sudoers ; TTY=pts/3 ; PWD=/home/testuser ; USER=root ; COMMAND=/usr/sbin/adduser hacker
```

The Wazuh alert payload confirmed:
- `srcuser`: testuser  
- `command`: /usr/sbin/adduser hacker  

This directly correlates to the attacker’s observed activity.

---

# Investigation

## Alert Triage

Wazuh events were reviewed for agent `sonarr` during the attack window. Following the configuration change, a Level 5 alert (Rule 5405) appeared with full command and user context.

Prior to enabling `auth.log` monitoring, identical activity produced no alerts, confirming a visibility gap.

---

## Detection Gap Analysis

The Sonarr Wazuh agent was not configured to monitor `/var/log/auth.log`, preventing authentication and sudo events from being forwarded to the SIEM.

The issue was resolved by adding:

```xml
<localfile>
  <location>/var/log/auth.log</location>
  <log_format>syslog</log_format>
</localfile>
```

After restarting the agent, the same activity immediately generated alerts without requiring any rule modifications.

---

## Activity Correlation

The alert timestamp aligned precisely with the attacker’s command execution in the SSH session.

Correlated data points:
- User: `testuser`  
- Command: `/usr/sbin/adduser hacker`  
- Outcome: Authorization denied  

This confirms the activity was malicious and not associated with legitimate administrative behavior.

---

## Control Validation

System configuration review confirmed:
- `testuser` is not in the sudo group  
- No sudoers exceptions are defined  

The operating system correctly enforced least privilege by denying the request.

Detection was then successfully layered on top via SIEM integration.

---

# Analyst Assessment

This phase highlights two critical realities of SOC operations:

1. **Detection is only as effective as log coverage**  
   The SIEM contained the correct detection logic but failed to alert due to incomplete log ingestion.

2. **Privilege escalation attempts do not require success to be dangerous**  
   Even failed attempts provide strong indicators of attacker intent and should be monitored.

The rapid identification and remediation of the logging gap transformed an invisible attack into a detectable event, demonstrating effective real-time detection engineering.

---

# Containment Actions

- Verified `testuser` has no sudo privileges  
- Enabled `/var/log/auth.log` monitoring on the Wazuh agent  
- Restarted agent and validated alert generation  
- Preserved logs and alert artifacts  
- Maintained attacker access for continued observation  

---

# Recommendations

| Recommendation | Purpose |
|---|---|
| Audit all Wazuh agents for missing log sources | Prevent similar visibility gaps |
| Standardize auth.log monitoring across endpoints | Ensure consistent detection coverage |
| Review sudo policies across all systems | Enforce least privilege consistently |
| Implement SSH key-based authentication | Reduce credential compromise risk |

---

# Key Findings

- Unauthorized sudo attempt successfully blocked by OS policy  
- Initial SIEM visibility gap identified and resolved during investigation  
- Built-in Wazuh rule provided detection without custom engineering  
- Agent-level log collection gaps can persist without validation  
- Defense-in-depth controls functioned as intended once telemetry was restored  

---

# Artifacts

- [Wazuh alert – Rule 5405 (Unauthorized sudo attempt)](artifacts/phase-03-sudo-alert.json)  
- [Raw auth.log segment – sudo denial](artifacts/phase-03-authlog.png)
