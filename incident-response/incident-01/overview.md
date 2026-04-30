# Incident 01 — Credential Brute‑Force to Privilege Escalation Attempt

**Date:** 2026‑04‑27 to 2026‑04‑30  
**Severity:** Medium (contained at every stage)  
**Status:** Closed — attacker blocked, detection validated, remediation planned

---

## Executive Summary
An attacker gained access to the **Sonarr** container in the lab’s private network by guessing a weak password. Over the next three days, they tried to map the internal network, create a backdoor account, and gain root access. Each attempt was either blocked by existing security controls or detected by our monitoring tools. No permanent access was gained, no services were disrupted, and no data was lost. A visibility gap in network monitoring was identified and will be closed with a future Suricata deployment.

## Incident Timeline

| Date | Phase | Event |
|------|-------|-------|
| 04‑27 | 1 | Attacker brute‑forces SSH credentials and logs into Sonarr |
| 04‑29 | 2 | Attacker scans internal subnet from the compromised container |
| 04‑29 | 3 | Attacker attempts `sudo adduser` to create a backdoor account |
| 04‑30 | 4 | Attacker attempts `su -` to become root |

All hostile actions occurred between **04‑27 and 04‑30** and were detected within minutes.

## Attack Summary

### Initial Access (Phase 1)
The attacker ran an automated password‑guessing tool against the SSH service of our **Sonarr** container. They successfully logged in with the username `testuser` and password `password123`. The system immediately generated alerts for multiple failed logins (brute‑force) and the final successful login.

[Full Phase 1 Report](phase-01/phase-01.md)

### Internal Reconnaissance (Phase 2)
Once inside, the attacker scanned the internal network to find other services. The scan was captured at the host level using a temporary firewall logging rule. Although the SIEM did not automatically alert on this activity, the evidence was preserved and the gap documented for a future tooling upgrade.

[Full Phase 2 Report](phase-02/phase-02.md)

### Attempted Persistence (Phase 3)
The attacker tried to use `sudo` to create a new user account (`hacker`) — a common technique to ensure continued access. The attempt failed because the compromised account did not have `sudo` privileges. Our monitoring system generated an alert within seconds.

[Full Phase 3 Report](phase-03/phase-03.md)

### Attempted Privilege Escalation (Phase 4)
In a second escalation attempt, the attacker tried to switch to the root account using `su -`. This also failed, and the failed authentication was immediately detected and logged.

[Full Phase 4 Report](phase-04/phase-04.md)

## Response Summary
- **Detection:** Wazuh SIEM alerted on the brute‑force login, the failed `sudo`, and the failed `su`. The internal scan was confirmed via manual host‑level investigation.
- **Containment:** The compromised account was confirmed to have no administrative privileges. All escalation attempts failed at the operating system level.
- **Evidence Collection:** All relevant logs, scan evidence, and SIEM alerts were preserved for the incident record.
- **Remediation:** A logging gap on the Sonarr container was corrected during the incident. A larger visibility gap for internal network scans is scheduled for permanent fix with Suricata IDS (Phase 7 of the lab roadmap).

## Impact Assessment
| Aspect | Impact |
|--------|--------|
| Data Loss | None |
| Service Disruption | None |
| Privilege Escalation | Unsuccessful |
| Persistence Achieved | None |
| Lateral Movement | None beyond initial host |

## Lessons Learned
1. **Weak passwords remain the primary entry vector.** Even a short dictionary attack succeeded in seconds. Password policies and SSH key‑only authentication would have prevented this entirely.
2. **Built‑in SIEM rules caught three of four attack phases.** No custom rules were required — just proper log collection.
3. **Container‑level logging limitations created a gap for network scans.** This will be resolved with the planned Suricata deployment, providing network‑level visibility independent of container configurations.
4. **Defense‑in‑depth worked as designed.** Even with a compromised account, the attacker could not escalate privileges or cause damage because of proper group membership and sudo policy enforcement.

## Next Steps
- Revoke the `testuser` account and remove the temporary firewall rules after the final incident review.
- Implement Phase 7 (Suricata IDS) to close the internal network visibility gap.
- Consider enforcing SSH key‑only authentication across all lab containers.
