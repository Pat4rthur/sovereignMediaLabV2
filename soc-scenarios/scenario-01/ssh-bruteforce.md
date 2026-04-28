# Scenario 1: SSH Brute-Force Attack Investigation

**Date:** 2026-04-27  
**Environment:** Sovereign Media Lab  
**Analyst:** Sovereign Media Lab SOC  
**Case Status:** Closed – Credential compromise confirmed and contained

---

# Executive Summary

A simulated SSH brute-force attack was conducted against the **Sonarr** container (`CT104`, `172.16.5.74`) from an isolated attacker container (`CT113`, `172.16.5.83`) to validate the lab’s ability to detect credential-access activity through Wazuh.

The attack leveraged a short dictionary wordlist using **Hydra v9.2** and successfully authenticated to the target system after multiple failed login attempts. Wazuh detected the authentication failures and subsequent successful session creation, generating alerts associated with MITRE ATT&CK techniques for password guessing and remote service abuse.

During investigation, an unexpected network anomaly initially obscured the true source of the attack. Analysis revealed that a `MASQUERADE` rule on the Proxmox hypervisor rewrote outbound LXC traffic to the host IP address, causing Wazuh logs to incorrectly identify the hypervisor as the source of the activity. Additional network analysis and log correlation confirmed the true attacker identity.

This scenario validated:
- Wazuh SSH authentication monitoring
- Alert triage and log analysis workflows
- Timeline reconstruction
- Network forensics and NAT troubleshooting
- MITRE ATT&CK mapping
- Basic containment procedures

---

# Scenario Objective

The purpose of this scenario was to simulate credential-access activity against a Linux endpoint and evaluate the SOC lab’s ability to:

- Detect repeated SSH authentication failures
- Identify successful unauthorized access attempts
- Investigate suspicious authentication telemetry
- Correlate endpoint and network evidence
- Perform basic incident response and containment

---

# Environment Overview

| System | Role | IP Address |
|---|---|---|
| CT104 – Sonarr | Target Endpoint | 172.16.5.74 |
| CT113 – Attacker | Simulated Threat Actor | 172.16.5.83 |
| Wazuh Manager | SIEM / Detection Platform | Internal |
| Proxmox Host | Hypervisor / NAT Gateway | 172.16.5.10 |

Logs were collected through `journald` and forwarded to Wazuh by agent `008` (`sonarr`).

---

# Attack Simulation

A dictionary-based SSH brute-force attack was executed from the attacker container using **Hydra v9.2** against the `testuser` account on the Sonarr container.

The attack used a small password list containing common weak credentials:

- `admin`
- `123456`
- `password`
- `letmein`
- `password123`

The final credential (`password123`) successfully authenticated to the target system.

This activity simulated real-world password guessing behavior commonly associated with opportunistic credential-access attacks targeting exposed SSH services.

---

# MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|---|---|---|
| Credential Access | Password Guessing | T1110.001 |
| Lateral Movement | Remote Services: SSH | T1021.004 |
| Discovery | System Network Configuration Discovery | T1016 |

---

# Detection and Telemetry

Wazuh generated multiple alerts associated with SSH authentication activity during the attack window.

## Alerts Triggered

| Rule ID | Description | Severity | Count |
|---|---|---|---|
| 5760 | `sshd: authentication failed` | Level 5 | 4 |
| 5501 | `PAM: Login session opened` | Level 5 | 1 |

A clear sequence emerged during analysis:

1. Multiple failed authentication attempts
2. Successful credential validation
3. SSH session creation

This pattern aligned with expected brute-force behavior.

---

# Log Evidence

Example authentication telemetry captured from `journalctl -u ssh`:

```text
Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36428 ssh2
Apr 27 17:24:38 sonarr sshd[147449]: Failed password for testuser from 172.16.5.10 port 36438 ssh2
...
Apr 27 17:24:39 sonarr sshd[147449]: Accepted password for testuser from 172.16.5.10 port 36448 ssh2
Apr 27 17:24:39 sonarr sshd[147449]: pam_unix(sshd:session): session opened for user testuser(uid=1000) by (uid=0)
```

Initial analysis suggested the attack originated from `172.16.5.10` — the Proxmox hypervisor — rather than the attacker container.

This discrepancy triggered additional investigation.

---

# Investigation

## 1. Alert Triage

Wazuh Security Events were filtered by:

- Agent: `sonarr`
- Rule ID: `5760`
- Time Window: `2026-04-27 12:24–12:25 UTC`

Threat Hunting visualizations showed a concentrated burst of failed authentication events immediately followed by a successful session creation event (`5501`).

This sequence indicated a likely successful brute-force attack rather than normal user authentication behavior.

---

## 2. Alert Deep Dive

Inspection of the Rule `5760` JSON payload revealed the following fields:

```json
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
```

The reported source IP did not match the expected attacker system (`172.16.5.83`), suggesting either:
- incorrect attribution,
- network address translation,
- or intermediary traffic routing.

This prompted a network-level investigation.

---

## 3. Network Forensics Analysis

Investigation of the Proxmox networking configuration identified the source of the discrepancy.

The following command confirmed that `172.16.5.10` belonged to the Proxmox hypervisor:

```bash
ip addr show | grep 172.16.5.10
```

Further inspection of NAT rules revealed an active `MASQUERADE` configuration:

```bash
iptables -t nat -L POSTROUTING -v -n
```

```text
MASQUERADE  all  --  *  vmbr0   172.16.5.0/24    0.0.0.0/0
```

Packet and byte counters confirmed that the rule was actively rewriting outbound traffic originating from the LXC subnet.

As a result:
- all authentication attempts appeared to originate from the hypervisor,
- masking the true attacker identity,
- and initially redirecting investigative focus toward the host itself.

---

## 4. Correlation of Successful Access

Analysis of the Rule `5501` alert confirmed that the successful login event followed the same translated network path.

Observed sequence:

- 4 failed SSH authentication attempts
- 1 successful authentication
- SSH session creation

This established a complete attack timeline and confirmed successful credential compromise.

---

## 5. Attribution Confirmation

The attacker container was reviewed directly to validate the source of the activity.

Hydra output confirmed successful authentication:

```text
[22][ssh] host: 172.16.5.74   login: testuser   password: password123
```

The Hydra execution timestamp aligned exactly with:
- Wazuh authentication alerts
- SSH session creation logs
- journalctl authentication telemetry

This correlation confirmed:

| System | Role |
|---|---|
| 172.16.5.83 | Actual attacker |
| 172.16.5.10 | NAT-translated hypervisor IP |

---

# Analyst Assessment

The investigation confirmed a successful dictionary-based SSH brute-force attack against a weak account credential.

The scenario also revealed an operational visibility issue caused by NAT translation on the Proxmox host, which complicated attribution and demonstrated the importance of understanding network architecture during incident response.

Key observations:
- Weak passwords remain highly vulnerable to automated credential attacks
- Authentication telemetry provided sufficient evidence for timeline reconstruction
- Network translation can significantly impact attribution accuracy in SIEM platforms
- Correlation across multiple evidence sources was required to accurately identify the attacker

---

# Containment Actions

The following containment measures were implemented:

- Locked the compromised `testuser` account
- Removed the temporary `MASQUERADE` rule for future scenarios
- Documented the NAT behavior for additional security review
- Preserved logs and screenshots for analysis documentation

---

# Recommendations

| Recommendation | Purpose |
|---|---|
| Enforce strong password policies | Reduce credential guessing risk |
| Disable password-based SSH authentication | Prevent brute-force login attempts |
| Implement SSH key authentication | Improve remote access security |
| Deploy Fail2Ban or equivalent controls | Automatically block repeated authentication failures |
| Review NAT visibility requirements | Improve attribution accuracy in SIEM telemetry |

---

# Lessons Learned

This scenario demonstrated that effective incident response depends not only on alert generation, but also on accurate interpretation of telemetry and network context.

Although Wazuh successfully detected the brute-force activity, NAT translation initially obscured attribution and introduced investigative ambiguity. Resolving the discrepancy required correlating:
- endpoint logs,
- SIEM alerts,
- firewall rules,
- and attacker-side tooling output.

This exercise reinforced the importance of:
- validating assumptions during investigations,
- understanding infrastructure-level networking behavior,
- and correlating multiple telemetry sources before drawing conclusions.

---

# Artifacts
- [Wazuh Security Events – 4×5760 + 1×5501](/soc-scenarios/scenario-01/artifacts/events.png)
- [Rule 5760 JSON payload – srcip 172.16.5.10](/soc-scenarios/scenario-01/artifacts/5760-json.json)
- [Hydra brute-force terminal output](/soc-scenarios/scenario-01/artifacts/hydra-output.png)
- [Proxmox iptables MASQUERADE rule](/soc-scenarios/scenario-01/artifacts/iptables-masquerade.png)
- [Threat Hunting report visualization](/soc-scenarios/scenario-01/artifacts/threat-hunt.png)
- [Raw authentication log segment](/soc-scenarios/scenario-01/artifacts/sshAuthLog.png)

