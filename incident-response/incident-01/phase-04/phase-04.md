# Phase 4: Privilege Escalation Attempt – su to Root

**Incident:** Incident‑01 – Credential Brute‑Force to Privilege Escalation Attempt  
**Phase:** 4 of 4  
**Date:** 2026‑04‑30  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Attempt blocked; detection validated

---

## Attack Description
Following the unsuccessful `sudo` attempt in Phase 3, the attacker pivoted to a different escalation path. Still operating from the compromised `testuser` account on the **Sonarr** container (CT104, `172.16.5.74`), the attacker ran the `su -` command with the intention of gaining root access.

The `su` command was attempted interactively and failed because `testuser` did not know the root password and was not a member of any privileged group that would allow passwordless `su`. The attempt generated an authentication failure.

**Tools used:** `su -` (built‑in Linux command)  
**Source host:** CT104 (`172.16.5.74`)  
**User context:** `testuser` (uid 1000)

## Log Evidence (Raw)
The `/var/log/auth.log` file on CT104 captured the failed authentication. The agent correctly shipped the log after the previous logging gap was closed in Phase 3.

**Relevant log line:**

`Apr 30 07:42:10 sonarr su[168242]: pam_unix(su:auth): authentication failure; logname=testuser uid=1000 euid=0 tty=/dev/pts/4 ruser=testuser rhost=`


## Wazuh Alerts Triggered
- **Rule 5301** — `su: authentication failure` (Level 5)

*MITRE ATT&CK tags from the Wazuh rule:*  
`T1078` — Valid Accounts

## Investigation Steps

### 1. Alert Triage
I filtered the Wazuh Security Events for agent `sonarr` around the time of the attacker’s activity. A Level 5 alert with rule ID 5301 appeared almost immediately after the agent re‑established its connection to the manager (a brief disconnection had occurred, which was resolved by restarting the `wazuh-agent` service on CT104).

### 2. Correlating with the Attacker Session
The timestamp of the `su` alert matched the moment the attacker entered the `su -` command in the interactive SSH session. The alert’s `full_log` field confirmed the command was run by `testuser` (uid `1000`), not a legitimate administrator, and that the authentication was rejected by the PAM subsystem.

### 3. Confirming the Attempt Was Denied
I verified on CT104 that `testuser` is not a member of any privileged group (`wheel`, `root`, etc.) and does not have access to the root password. The `su` attempt was correctly blocked, and the failed authentication was immediately logged and shipped to Wazuh — demonstrating that the logging pipeline built in Phase 3 continues to function.

## Conclusion
This final phase of the incident shows the attacker systematically exploring multiple privilege escalation paths (`sudo`, then `su`). Each attempt was blocked by the operating system’s security configuration and detected by a built‑in Wazuh rule with no custom detection engineering required.

Across all four phases, the kill chain was contained at every step:
- **Phase 1:** Brute‑force login detected (rule 5760, 5715)
- **Phase 2:** Internal reconnaissance confirmed via host‑level evidence
- **Phase 3:** `sudo` attempt blocked and detected (rule 5405)
- **Phase 4:** `su` attempt blocked and detected (rule 5301)

The attacker failed to escalate privileges or create a persistent backdoor account, and every significant action was either detected in real‑time or captured as forensic evidence.

**Containment Actions Taken:**
- Confirmed `testuser` has no privileged access.
- V Verified that the Wazuh agent recovers gracefully from disconnections and forwards queued events.
- The temporary SSH allow rule, the `testuser` account, and the `iptables` LOG rule remain in place until the full incident lifecycle is complete and will be revoked after the final overview report.

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Privilege Escalation | Valid Accounts | T1078 |

## Artifacts
- [Wazuh alert – Rule 5301 (su authentication failure)](artifacts/phase-04-su-alert.png)
- [Raw auth.log segment – su failure](artifacts/phase-04-authlog.txt)
