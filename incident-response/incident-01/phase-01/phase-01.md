# Phase 1: SSH Brute‑Force Attack

**Incident:** Incident‑01 – Credential Brute‑Force to Privilege Escalation Attempt  
**Phase:** 1 of 4  
**Date:** 2026‑04‑27  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Closed – Credential compromise confirmed and contained

---

## Attack Description
A simulated attacker operated from an isolated container (**CT113**, `172.16.5.83`) and targeted the **Sonarr** container (**CT104**, `172.16.5.74`). They ran a dictionary‑based SSH brute‑force attack against a deliberately weak account (`testuser`) using **Hydra v9.2**.

The wordlist contained five entries: `admin`, `123456`, `password`, `letmein`, and `password123`. After four failed attempts, the final entry succeeded, granting the attacker an interactive SSH session. The Proxmox host (`172.16.5.10`) acted as a NAT gateway for the LXC subnet, which would later complicate attribution.

**Tools used:** Hydra v9.2  
**Target user:** `testuser`  
**Password list:** `admin`, `123456`, `password`, `letmein`, `password123`

## Log Evidence (Raw)
All authentication events were captured by `journald` on CT104 and shipped to Wazuh by agent `008` (`sonarr`).

**Example log entries from `journalctl -u ssh`:**

`Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36428 ssh2`

`Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36438 ssh2
...`

`Apr 27 17:24:39 sonarr sshd[147449]: Accepted password for testuser from 172.16.5.10 port 36448 ssh2`

`Apr 27 17:24:39 sonarr sshd[147449]: pam_unix(sshd:session): session opened for user testuser(uid=1000) by (uid=0)`


*Note:* Every log entry shows a source IP of **172.16.5.10** (the Proxmox host), not the attacker’s real IP. This was caused by an active `MASQUERADE` rule on the hypervisor and became a central part of the investigation.

## Wazuh Alerts Triggered
- **Rule 5760** — `sshd: authentication failed.` (Level 5) — Fired 4 times.
- **Rule 5501** — `PAM: Login session opened.` (Level 5) — Fired once after the successful login.

*MITRE ATT&CK tags from Wazuh rules:*  
`T1110.001` — Password Guessing  
`T1021.004` — Remote Services: SSH

## Investigation Steps

### 1. Alert Triage
I filtered the Wazuh Security Events by agent `sonarr` and rule ID `5760` for the attack window (`2026‑04‑27 12:24–12:25 UTC`). The Threat Hunting report showed a tight cluster of four failed authentication events immediately followed by a single `5501` (PAM session opened). This sequence was consistent with a successful dictionary attack, not normal user behaviour.

### 2. Alert Deep Dive (Rule 5760)
Expanding one `5760` alert revealed the full JSON payload. The `data.srcip` field was **172.16.5.10** — the Proxmox host’s management IP — not the expected attacker IP `172.16.5.83`. This discrepancy meant either the attribution was wrong, network translation was in play, or traffic was being relayed. I expanded the investigation to the network layer.

### 3. Network Anomaly Analysis
On the Proxmox host, I confirmed that `172.16.5.10` belonged to the `vmbr0` bridge interface. Running `iptables -t nat -L POSTROUTING -v -n` revealed an active MASQUERADE rule:

`MASQUERADE all -- * vmbr0 172.16.5.0/24 0.0.0.0/0`


That confirmed the true attacker was **172.16.5.83**. The MASQUERADE rule had masked the real source IP, requiring correlation across endpoint logs, SIEM events, and attacker tool output before I could definitively attribute the activity.

## Conclusion
The brute‑force attack succeeded because of a weak password on the `testuser` account. Wazuh detected both the failures and the subsequent login, and the investigation uncovered an unexpected network anomaly (host‑level NAT) that initially obscured the true attacker. Resolving that anomaly reinforced the importance of understanding the underlying infrastructure when working with SIEM telemetry.

**Containment Actions Taken:**
- Locked the `testuser` account.
- Removed the temporary `MASQUERADE` rule for later investigation phases.
- Documented the NAT behaviour and the detection gap it introduced.
- Preserved all logs, alerts, and Hydra output as incident artefacts.

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Credential Access | Password Guessing | T1110.001 |
| Lateral Movement | Remote Services: SSH | T1021.004 |
| Discovery | System Network Configuration Discovery | T1016 |

## Artifacts
- [Wazuh Security Events – 4×5760 + 1×5501](artifacts/events.png)
- [Rule 5760 JSON payload – srcip 172.16.5.10](artifacts/5760-json.json)
- [Hydra brute‑force terminal output](artifacts/hydra-output.png)
- [Proxmox iptables MASQUERADE rule](artifacts/iptables-masquerade.png)
- [Threat Hunting report visualization](artifacts/threat-hunt.png)
- [Raw authentication log segment](artifacts/sshAuthLog.png)
