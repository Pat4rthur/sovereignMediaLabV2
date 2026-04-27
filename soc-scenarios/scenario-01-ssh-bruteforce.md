# Scenario 1: SSH Brute-Force Attack

**Date:** 2026-04-27  
**Analyst:** Sovereign Media Lab SOC  
**Status:** Closed – Attacker identified, containment complete

---

## Attack Description
An attacker performed a dictionary-based SSH brute-force attack against the **Sonarr** container (CT104, `172.16.5.74`) from the **attacker** container (CT113, `172.16.5.83`). The attack used a short password list of 5 entries, with the last attempt (`password123`) succeeding against the weak user `testuser`. The majority of login attempts failed, generating a burst of authentication failure alerts in Wazuh.

**Tools used:** Hydra v9.2  
**Target user:** `testuser`  
**Password list:** `admin`, `123456`, `password`, `letmein`, `password123`
## Log Evidence (Raw)
All SSH authentication logs were captured via `journald` and shipped to Wazuh by agent `008` (sonarr). Example raw log from `journalctl -u ssh`:

    Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36428 ssh2
    Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36438 ssh2
    ...
    Apr 27 17:24:39 sonarr sshd[147449]: Accepted password for testuser from 172.16.5.10 port 36448 ssh2
    Apr 27 17:24:39 sonarr sshd[147449]: pam_unix(sshd:session): session opened for user testuser(uid=1000) by (uid=0)

*Note:* The source IP recorded in logs is **172.16.5.10** (Proxmox host) due to a masquerade NAT rule. See investigation steps for full analysis.

## Wazuh Alerts Triggered
- **Rule 5760** — `sshd: authentication failed.` (Level 5) — Fired 4 times.
- **Rule 5501** — `PAM: Login session opened.` (Level 5) — Fired once upon successful login.

*MITRE ATT&CK tags from Wazuh rules:*  
`T1110.001` — Password Guessing  
`T1021.004` — Remote Services: SSH

## Investigation Steps

### 1. Alert Triage
Opened Wazuh Security Events, filtered by agent `sonarr` and rule ID `5760` for the attack window (`2026-04-27 12:24–12:25 UTC`). The Threat Hunting report showed a distinct spike of 5760 alerts (4 events) followed by a single 5501 event.

### 2. Alert Deep Dive (Rule 5760)
Expanded one 5760 alert and viewed the full JSON payload. Key fields:

    "agent": {
      "ip": "172.16.5.74",
      "name": "sonarr",
      "id": "008"
    },
    "data": {
      "srcip": "172.16.5.10",
      "dstuser": "testuser",
      "srcport": "36444"
    },
     "full_log": "Apr 27 17:24:38 sonarr sshd[147450]: Failed password for testuser from 172.16.5.10 port 36444 ssh2"

**Discrepancy:** The `srcip` (`172.16.5.10`) did not match the expected attacker IP (`172.16.5.83`). This triggered a network forensics investigation.

### 3. Network Anomaly Analysis
- Used `ip addr show | grep 172.16.5.10` on the Proxmox host. Confirmed that **172.16.5.10** is the hypervisor's management IP on `vmbr0`.
- Ran `iptables -t nat -L POSTROUTING -v -n` on Proxmox host, revealing an active MASQUERADE rule:

      MASQUERADE  all  --  *  vmbr0   172.16.5.0/24    0.0.0.0/0

  Packet/byte counters (`893K 69M`) confirmed the rule was actively rewriting all traffic from the LXC subnet to the host's IP.

### 4. Correlation to Successful Login
- Opened the Rule 5501 alert (`PAM: Login session opened`). The `srcip` field also showed **172.16.5.10**, confirming that the successful session was routed through the same SNAT path as the failed attempts.
- Verified that the user `testuser` was successfully authenticated at the exact time of the brute‑force, creating a complete timeline:
  - 4 failed attempts → 1 success → session opened.

### 5. Confirmation of True Attacker Identity
- On the attacker container (CT113), verified the `hydra` output:

      [22][ssh] host: 172.16.5.74   login: testuser   password: password123

- Cross‑referenced the `hydra` success timestamp with the Wazuh alert timestamps → exact match.
- **Conclusion:** The real attacker IP was `172.16.5.83`. The per‑host `MASQUERADE` rule obscured the true source, initially pointing investigation toward the hypervisor itself.### 5. Confirmation of True Attacker Identity
- On the attacker container (CT113), verified the `hydra` output:

      [22][ssh] host: 172.16.5.74   login: testuser   password: password123

- Cross‑referenced the `hydra` success timestamp with the Wazuh alert timestamps → exact match.
- **Conclusion:** The real attacker IP was `172.16.5.83`. The per‑host `MASQUERADE` rule obscured the true source, initially pointing investigation toward the hypervisor itself.

- ## Conclusion
**Root Cause:** A weak password for the `testuser` account allowed a successful dictionary-based brute-force attack in under five attempts.

**Network Anomaly:** An unexpected `MASQUERADE` rule on the Proxmox host rewrote all outbound LXC traffic to the host's own IP, masking the true attacker identity and redirecting initial suspicion toward the hypervisor.

**Containment Actions Taken:**
- Locked the `testuser` account (`passwd -l testuser`)
- Temporarily removed the MASQUERADE rule (non‑persistent) for subsequent scenarios
- Documented the rule for further security review

## MITRE ATT&CK Mapping
| Tactic | Technique | ID |
|--------|-----------|----|
| Credential Access | Password Guessing | T1110.001 |
| Lateral Movement | Remote Services: SSH | T1021.004 |

**Additional mapping from investigation:**

| Tactic | Technique | ID |
|--------|-----------|----|
| Discovery | System Network Configuration Discovery | T1016 |

## Artifacts
- [Wazuh Security Events – 4×5760 + 1×5501](soc-scenarios/artifacts/scenario-01/events.png)
- [Rule 5760 JSON payload – srcip 172.16.5.10](soc-scenarios/artifacts/scenario-01/5760-json.png)
- [Hydra brute‑force terminal output](soc-scenarios/artifacts/scenario-01/hydra-output.png)
- [Proxmox iptables MASQUERADE rule](soc-scenarios/artifacts/scenario-01/iptables-masquerade.png)
- [Threat Hunting report bar chart](soc-scenarios/artifacts/scenario-01/threat-hunt.png)
- [Raw auth.log segment](soc-scenarios/artifacts/scenario-01/authlog.txt)
