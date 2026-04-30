# Phase 4: Privilege Escalation Attempt – `su` to Root

**Incident:** Incident-01 – Credential Brute-Force to Privilege Escalation Attempt  
**Phase:** 4 of 4  
**Date:** 2026-04-30  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Attempt blocked – Detection validated  

---

# Executive Summary

Following failed privilege escalation attempts via `sudo` (Phase 3), the attacker shifted tactics and attempted to escalate directly to root using `su -`.

The attempt failed due to lack of root credentials and generated an authentication failure event. The alert was successfully detected by Wazuh (Rule 5301), although a brief agent disconnection delayed ingestion. Once the agent reconnected, queued events were forwarded and the alert was generated without data loss.

This phase confirms:
- Detection of `su` authentication failures via built-in SIEM rules  
- Resilience of the Wazuh agent buffering mechanism during transient disconnection  
- Attacker escalation pattern shift across multiple techniques  
- Full coverage of post-compromise escalation attempts across all phases  

---

# Severity & Impact

**Severity:** Medium  

**Impact:**  
A successful `su -` to root would have granted full administrative control over the container, enabling persistence, lateral movement, and potential destruction or exfiltration of data.

The attempt was blocked at the authentication layer, and the failure was logged and subsequently detected. No escalation was achieved.

---

# Phase Objective

This phase evaluated the SOC’s ability to:

- Detect failed `su` authentication attempts via SIEM rules  
- Maintain telemetry integrity during transient agent outages  
- Correlate authentication failures with attacker session activity  
- Validate multi-vector privilege escalation defense coverage  

---

# Environment Overview

| System | Role | IP Address |
|---|---|---|
| CT104 – Sonarr | Compromised Host | 172.16.5.74 |
| Wazuh Manager | SIEM Platform | Internal |

The system runs Ubuntu 22.04 with CIS-aligned hardening. The `testuser` account has no sudo privileges and no knowledge of the root password. Authentication events are collected via `/var/log/auth.log` through Wazuh agent `008`.

---

# Attack Simulation

From the existing SSH session, the attacker executed:

```bash
su -
```

When prompted for credentials, the attacker supplied the same password used for the compromised account (`testuser`). Authentication failed at the PAM layer because root credentials were not provided.

This attempt followed unsuccessful escalation via `sudo`, indicating adaptive behavior and systematic probing of privilege escalation vectors.

---

# MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Privilege Escalation | Valid Accounts | T1078 |

---

# Detection & Telemetry

## Alerts Triggered

- **Rule 5301** — `su: authentication failure` (Level 5)

The alert was generated after the Wazuh agent recovered from a brief disconnection. Events were queued locally and forwarded upon reconnection.

---

# Timeline of Events

| Time (UTC) | Event |
|---|---|
| 04-30 07:42 | Attacker executes `su -`; authentication fails |
| 04-30 07:42 | Wazuh agent briefly disconnects |
| 04-30 07:43 | Agent reconnects; queued logs forwarded |
| 04-30 07:43 | Rule 5301 alert generated in Wazuh |

---

# Log Evidence

```text
Apr 30 07:42:10 sonarr su[168242]: pam_unix(su:auth): authentication failure; 
logname=testuser uid=1000 euid=0 tty=/dev/pts/4 ruser=testuser rhost=
```

The Wazuh alert confirmed:
- `srcuser`: testuser  
- authentication failure event captured via PAM  

This aligns directly with attacker session activity.

---

# Investigation

## Alert Triage

After agent recovery, Wazuh Security Events were filtered for `sonarr`. A Level 5 alert (Rule 5301) appeared immediately and matched the authentication failure log entry.

---

## Agent Disconnection Behavior

The Wazuh agent briefly entered a disconnected state during the attack window. No manual intervention was required; the agent automatically resumed communication.

Critically:
- Logs generated during the outage were **buffered locally**
- Events were **forwarded upon reconnection**
- No telemetry loss occurred

This confirms resilience of the agent’s store-and-forward behavior under short outages.

---

## Attacker Behavior Correlation

The `su` attempt followed a failed `sudo` escalation in Phase 3, indicating adaptive escalation behavior:

- Phase 3: Attempted privilege escalation via `sudo`
- Phase 4: Shifted to direct root authentication via `su`

This reflects realistic attacker progression through available privilege escalation paths.

---

# Analyst Assessment

Across all four phases, the attacker attempted:
- credential compromise (Phase 1)
- internal reconnaissance (Phase 2)
- privilege escalation via sudo (Phase 3)
- privilege escalation via su (Phase 4)

Each attempt was:
- blocked by OS-level controls, or
- detected via built-in SIEM rules once logging was properly configured

No custom detection logic was required for any phase.

The only operational anomaly was a transient SIEM agent disconnection, which did not result in data loss due to buffering behavior.

---

# Containment Actions

- Verified `testuser` has no privileged access or root credentials  
- Confirmed Wazuh agent recovery and log replay functionality  
- Maintained monitoring state for full incident lifecycle  
- Preserved authentication logs and alert artifacts  

---

# Recommendations

| Recommendation | Purpose |
|---|---|
| Implement continuous agent health monitoring | Detect silent telemetry gaps faster |
| Maintain auth.log ingestion across all systems | Ensure consistent authentication visibility |
| Enforce SSH key-only authentication | Remove password-based escalation surface |
| Standardize log buffering expectations in design | Account for short agent outages in SOC modeling |

---

# Key Findings

- `su` authentication failure successfully detected via Rule 5301  
- Attacker escalated through multiple privilege techniques after repeated failure  
- Wazuh agent outage did not result in data loss due to buffering  
- Full attack chain detected or reconstructed without custom rules  
- Defense-in-depth controls consistently prevented escalation attempts  

---

# Artifacts

- [Wazuh alert – Rule 5301 (su authentication failure)](artifacts/phase-04-su-alert.png)  
- [Raw auth.log segment – su failure](artifacts/phase-04-authlog.txt)
