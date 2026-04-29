# Phase 3: Privilege Escalation Attempt – Unauthorized sudo

**Incident:** Incident‑01 – Credential Brute‑Force to Privilege Escalation Attempt  
**Phase:** 3 of 4  
**Date:** 2026‑04‑29  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Attempt blocked; detection validated

---

## Attack Description
After establishing a foothold on the **Sonarr** container (CT104, `172.16.5.74`) via compromised credentials (`testuser:password123`), the attacker attempted to create a new user account (`hacker`) using `sudo adduser hacker`. The goal was likely persistence—ensuring continued access even if the `testuser` password were changed.

The command was run from an interactive SSH session as `testuser`.  
Because `testuser` is **not** a member of the `sudo` group and has no explicit `sudoers` entry, the attempt was denied by the system’s sudo policy.

## Log Evidence (Raw)
The attempt generated clear entries in `/var/log/auth.log`. After the Wazuh agent logging gap was closed (see Investigation Step 3), the event was forwarded to the SIEM.

**Relevant log lines:**
`Apr 29 15:27:04 sonarr sudo[163686]: testuser : user NOT in sudoers ; TTY=pts/3 ; PWD=/home/testuser ; USER=root ; COMMAND=/usr/sbin/adduser hacker`

**Note:** The earlier `sudo -n` attempts without a password did not trigger this alert because sudo requires authentication before it authorizes the command. Only when the correct password was supplied did the “user NOT in sudoers” message appear and get captured.

## Wazuh Alerts Triggered
- **Rule 5405** — `Unauthorized user attempted to use sudo.` (Level 5)

*MITRE ATT&CK tags from the Wazuh rule:*  
`T1548.003` — Sudo and Sudo Caching  
**Tactics:** Privilege Escalation, Defense Evasion

## Investigation Steps

### 1. Alert Triage
I filtered the Wazuh Security Events for agent `sonarr` around the time of the known attacker activity. A Level 5 alert with rule ID 5405 appeared, describing an unauthorized sudo attempt. The alert’s full log showed the user `testuser`, the command `/usr/sbin/adduser hacker`, and the denial reason.

### 2. Correlating with the Attacker Session
The timestamp of the alert matched the moment the attacker typed `sudo adduser hacker` in the SSH session. The command exactly matched what the attacker described attempting. The alert’s `data.srcuser` field confirmed the user was `testuser`, not root or a legitimate administrator.

### 3. Fixing the Logging Gap
The Wazuh agent on CT104 was not initially shipping `/var/log/auth.log` to the manager, despite the events being recorded locally. This was discovered when earlier `sudo` attempts did not produce SIEM alerts.  
I edited the agent’s configuration and added a `<localfile>` block for `/var/log/auth.log`, then restarted the agent. Immediately after, the unauthorized attempt triggered rule 5405 without any custom rule changes.

**Reference:** The same logging gap was later documented in `docs/troubleshooting.md` with the remediation.

### 4. Confirming the Attempt Was Denied
I verified that `testuser` is not in the `sudo` group and has no special privileges. The `sudo` policy correctly rejected the command. The attacker’s attempt to create a persistent backdoor account failed.

## Conclusion
This phase demonstrates that **even a low‑privileged account can be used for dangerous actions**, but that **proper sudo policy enforcement prevents escalation**. The attempt was immediately denied by the operating system and detected by a built‑in Wazuh rule—no custom detection engineering was required once the basic logging configuration was corrected.

**Containment Actions Taken:**
- Verified that `testuser` does not have `sudo` privileges.
- Left the account active to continue monitoring the attacker’s behavior (account will be revoked after the full incident lifecycle).
- Enabled `auth.log` monitoring on the Sonarr Wazuh agent to prevent future detection gaps.

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Privilege Escalation | Sudo and Sudo Caching | T1548.003 |
| Persistence | Create Account (attempted) | T1136.001 |

## Artifacts
- [Wazuh alert – Rule 5405 (Unauthorized sudo attempt)](artifacts/phase-03-sudo-alert.png)
- [Raw auth.log segment – sudo denial](artifacts/phase-03-authlog.txt)
**Note:** The earlier `sudo -n` attempts without a password did not trigger this alert because sudo requires authentication before it authorizes the command. Only when the correct password was supplied did the “user NOT in sudoers” message appear and get captured.

## Wazuh Alerts Triggered
- **Rule 5405** — `Unauthorized user attempted to use sudo.` (Level 5)

*MITRE ATT&CK tags from the Wazuh rule:*  
`T1548.003` — Sudo and Sudo Caching  
**Tactics:** Privilege Escalation, Defense Evasion

## Investigation Steps

### 1. Alert Triage
I filtered the Wazuh Security Events for agent `sonarr` around the time of the known attacker activity. A Level 5 alert with rule ID 5405 appeared, describing an unauthorized sudo attempt. The alert’s full log showed the user `testuser`, the command `/usr/sbin/adduser hacker`, and the denial reason.

### 2. Correlating with the Attacker Session
The timestamp of the alert matched the moment the attacker typed `sudo adduser hacker` in the SSH session. The command exactly matched what the attacker described attempting. The alert’s `data.srcuser` field confirmed the user was `testuser`, not root or a legitimate administrator.

### 3. Fixing the Logging Gap
The Wazuh agent on CT104 was not initially shipping `/var/log/auth.log` to the manager, despite the events being recorded locally. This was discovered when earlier `sudo` attempts did not produce SIEM alerts.  
I edited the agent’s configuration and added a `<localfile>` block for `/var/log/auth.log`, then restarted the agent. Immediately after, the unauthorized attempt triggered rule 5405 without any custom rule changes.

**Reference:** The same logging gap was later documented in `docs/troubleshooting.md` with the remediation.

### 4. Confirming the Attempt Was Denied
I verified that `testuser` is not in the `sudo` group and has no special privileges. The `sudo` policy correctly rejected the command. The attacker’s attempt to create a persistent backdoor account failed.

## Conclusion
This phase demonstrates that **even a low‑privileged account can be used for dangerous actions**, but that **proper sudo policy enforcement prevents escalation**. The attempt was immediately denied by the operating system and detected by a built‑in Wazuh rule—no custom detection engineering was required once the basic logging configuration was corrected.

**Containment Actions Taken:**
- Verified that `testuser` does not have `sudo` privileges.
- Left the account active to continue monitoring the attacker’s behavior (account will be revoked after the full incident lifecycle).
- Enabled `auth.log` monitoring on the Sonarr Wazuh agent to prevent future detection gaps.

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Privilege Escalation | Sudo and Sudo Caching | T1548.003 |
| Persistence | Create Account (attempted) | T1136.001 |

## Artifacts
- [Wazuh alert – Rule 5405 (Unauthorized sudo attempt)](artifacts/phase-03-sudo-alert.json)
- [Raw auth.log segment – sudo denial](artifacts/phase-03-authlog.png)
